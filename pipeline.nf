#!/usr/bin/env nextflow

process myrdfunit {
    container "aksw/rdfunit"
    debug true

    input:
      path shapes from "$projectDir/maturityModel/shapes.ttl"

    output:
      file "./RDFUnit_manual_results.ttl" into results

    """
    java -jar /app/rdfunit-validate.jar -A -v -d $projectDir/data.ttl -s $shapes -r shacl -o turtle -C -f /tmp/
    cp /tmp/results/._data.ttl.shaclTestCaseResult.ttl ./RDFUnit_manual_results.ttl
    """
}

process print__ {
  container "ubuntu"

  input:
    path results

  output:
    stdout o

  """
  echo ${RDFUnit_manual_results}
  """
}

//workflow {
//  myrdfunit | print__ | view
//}
