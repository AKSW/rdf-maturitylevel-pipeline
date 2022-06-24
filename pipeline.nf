#!/usr/bin/env nextflow

// Variables - local use only
myUUID = UUID.randomUUID().toString()
myQMD_URI = "$QMD_NAMESPACE"+myUUID

process rdfunit {
    container "aksw/rdfunit"
    containerOptions '--entrypoint="/bin/bash"'
    debug true

    input:
      path data from "$projectDir/$FILE_DATA"
      // shapes does only work here when used directly in the cmd

    output:
      file "./RDFUnit_manual_results.ttl" into result_rdfunit

    """
    java -jar /app/rdfunit-validate.jar -A -v -d $data -s $projectDir/$FILE_SHAPES -r shacl -o turtle -C -f /tmp/
    cp /tmp/results/data.ttl.shaclTestCaseResult.ttl ./RDFUnit_manual_results.ttl
    """
}

process seeAlsoCreation {
    container "aklakan/rdf-processing-toolkit"
    debug true

    input:
      path shapes from "$projectDir/$FILE_SHAPES"

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
      path maturitymodel from "$projectDir/$FILE_MODEL"

    output:
      file "./main.ttl" into result_concat

    """
    rapper -o ntriples -i turtle $maturitymodel > concat.n3
    rapper -o ntriples -i turtle $result_rdfunit >> concat.n3
    rapper -o ntriples -i turtle $result_seeAlsoCreation >> concat.n3
    rapper -o turtle -i ntriples ./concat.n3 > ./main.ttl
    """
}

process manipulation {
    container "tboonx/rpt:jena-4.6.0"
    debug true

    input:
      path result_concat
      path updateSource from "$projectDir/sparql/updateSource.rq"
      path createMetricRelation from "$projectDir/sparql/createMetricRelation.rq"
      path createQMD from "$projectDir/sparql/createQMD.rq"
      path createQM from "$projectDir/sparql/createQM.rq"
      path updateValues from "$projectDir/sparql/updateValues.rq"
      path detectMaturityLevel from "$projectDir/sparql/detectMaturityLevel.rq"

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
