#!/bin/bash

# TODO use execution parameter as file paths
file_data="data.ttl"
file_shapes="maturityModel/shapes.ttl"
file_model="maturityModel/maturitymodel.ttl"
export datasource_identifier="http://example.de/dataset1" # using .graph file?
LIB_RPT="java -jar ../../rpt.jar"
UUID=$(uuidgen)
URI="http://stream-ontology.com/maturitymodel/executions/"
export QMD_URI="$URI$UUID"

# run RDFUnit
docker run --rm -it --entrypoint="/bin/bash" -v $PWD:/app/my aksw/rdfunit -c "cd my && java -jar /app/rdfunit-validate.jar -A -v -d ./$file_data -s ./$file_shapes -r shacl -o turtle -C -f /tmp/ && cp /tmp/results/._data.ttl.shaclTestCaseResult.ttl /app/my/RDFUnit_manual_results.ttl && chmod 777 ./RDFUnit_manual_results.ttl"

echo "---------------------------------"

# prepare main.ttl with maturity model, RDFUnit results and shape triples
cat $file_model > concat.ttl
cat ./RDFUnit_manual_results.ttl >> concat.ttl
$LIB_RPT integrate -o=seeAlso.ttl --out-format=TTL ./maturityModel/shapes.ttl 'construct { ?shape rdfs:seeAlso ?metric }  where {?shape a <http://rdfunit.aksw.org/ns/core#ManualTestCase>; rdfs:seeAlso ?metric }'
cat ./seeAlso.ttl >> concat.ttl
docker run --rm -it --entrypoint="/bin/bash" -v $PWD:/app pheyvaer/raptor -c "cd /app && rapper -o turtle -i turtle ./concat.ttl > ./main.ttl && chmod 777 ./main.ttl"

echo "---------------------------------"

# change datasource iri - from file to URL
$LIB_RPT integrate main.ttl updateSource.rq spo.rq | tail -n+2 > edited.ttl # spo.rq is a fixed name

echo "---------------------------------"

# add metric to ns0:TestCaseResult
$LIB_RPT integrate edited.ttl createMetricRelation.rq spo.rq | tail -n+2 > constructed_metrics.ttl # spo.rq is a fixed name

echo "---------------------------------"

# create QMD
$LIB_RPT integrate constructed_metrics.ttl createQMD.rq spo.rq | tail -n+2 > constructed_qmd.ttl # spo.rq is a fixed name

echo "---------------------------------"

# create QMs
$LIB_RPT integrate constructed_qmd.ttl createQM.rq spo.rq | tail -n+2 > constructed_qms.ttl # spo.rq is a fixed name

echo "---------------------------------"

# set values of failed metrics to zero
$LIB_RPT integrate constructed_qms.ttl updateValues.rq spo.rq | tail -n+2 > updatedValues.ttl # spo.rq is a fixed name

echo "---------------------------------"

# detect MaturityLevel and add it
$LIB_RPT integrate updatedValues.ttl detectMaturityLevel.rq spo.rq | tail -n+2 > final.ttl # spo.rq is a fixed name

echo "---------------------------------"
