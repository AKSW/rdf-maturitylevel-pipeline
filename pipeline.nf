#!/usr/bin/env nextflow

// Files - do not work
// some files have to be input and others direct parameter in the command
//shapes = file("maturityModel/shapes.ttl")
//data = file("data.ttl")
//model = file("maturityModel/maturitymodel.ttl")

// Variables - they have to be exported into each container where they are needed
mydatasource_identifier="http://example.de/dataset1"
myUUID = UUID.randomUUID().toString()
myQMD_URI = "http://stream-ontology.com/maturitymodel/executions/"+myUUID

process rdfunit {
    container "aksw/rdfunit"
    containerOptions '--entrypoint="/bin/bash"'
    debug true

    input:
      path data from "$projectDir/data.ttl"
      // shapes does only work here when used directly in the cmd

    output:
      file "./RDFUnit_manual_results.ttl" into result_rdfunit

    """
    java -jar /app/rdfunit-validate.jar -A -v -d $data -s $projectDir/maturityModel/shapes.ttl -r shacl -o turtle -C -f /tmp/
    cp /tmp/results/data.ttl.shaclTestCaseResult.ttl ./RDFUnit_manual_results.ttl
    """
}

process seeAlsoCreation {
    container "aklakan/rdf-processing-toolkit"
    debug true

    input:
      path shapes from "$projectDir/maturityModel/shapes.ttl"

    output:
      file "seeAlso.ttl" into result_seeAlsoCreation

    """
    export datasource_identifier=$mydatasource_identifier
    java -cp @/app/jib-classpath-file org.aksw.rdf_processing_toolkit.cli.main.MainCliRdfProcessingToolkit integrate -o=seeAlso.ttl --out-format=TTL $shapes 'construct { ?shape rdfs:seeAlso ?metric }  where {?shape a <http://rdfunit.aksw.org/ns/core#ManualTestCase>; rdfs:seeAlso ?metric }'
    """
}

process concat {
    container "pheyvaer/raptor"
    containerOptions '--entrypoint="/bin/bash"'
    debug true

    input:
      path result_rdfunit
      path result_seeAlsoCreation
      path maturitymodel from "$projectDir/maturityModel/maturitymodel.ttl"

    output:
      file "./main.ttl" into result_concat

    """
    cat $maturitymodel > concat.ttl
    cat $result_rdfunit >> concat.ttl
    cat $result_seeAlsoCreation >> concat.ttl
    rapper -o turtle -i turtle ./concat.ttl > ./main.ttl
    """
}

process manipulation {
    container "tboonx/rpt:jena-4.6.0"
    debug true

    input:
      path result_concat
      path updateSource from "$projectDir/updateSource.rq"
      path createMetricRelation from "$projectDir/createMetricRelation.rq"
      path createQMD from "$projectDir/createQMD.rq"
      path createQM from "$projectDir/createQM.rq"
      path updateValues from "$projectDir/updateValues.rq"
      path detectMaturityLevel from "$projectDir/detectMaturityLevel.rq"

    output:
      file "final.ttl" into result_manipulation

    """
    export datasource_identifier=$mydatasource_identifier
    export QMD_URI=$myQMD_URI
    java -jar /rpt.jar integrate $result_concat $updateSource spo.rq | tail -n+2 > edited.ttl
    java -jar /rpt.jar integrate edited.ttl $createMetricRelation spo.rq | tail -n+2 > constructed_metrics.ttl
    java -jar /rpt.jar integrate constructed_metrics.ttl $createQMD spo.rq | tail -n+2 > constructed_qmd.ttl
    java -jar /rpt.jar integrate constructed_qmd.ttl $createQM spo.rq | tail -n+2 > constructed_qms.ttl
    java -jar /rpt.jar integrate constructed_qms.ttl $updateValues spo.rq | tail -n+2 > updatedValues.ttl
    java -jar /rpt.jar integrate updatedValues.ttl $detectMaturityLevel spo.rq | tail -n+2 > final.ttl
    """
}


process print__ {
  container "ubuntu"
  debug true

  input:
    path result_manipulation

  output:
    stdout o

  """
  cat $result_manipulation
  """
}
