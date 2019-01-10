#!/usr/bin/env bash

# arguments
#########################################################################################
make_example_out=$1
bed_path=$2
ref_version=$3
contig_style=$4
call_variants_out=$5

# variables
#########################################################################################
spark=/usr/bin/spark-submit
executor_vcores=2
num_vcores=`curl http://localhost:8088/ws/v1/cluster/metrics | \
            python -c "import sys, json; print json.load(sys.stdin)['clusterMetrics']['totalVirtualCores']"`
num_nodes=`curl http://localhost:8088/ws/v1/cluster/metrics | \
            python -c "import sys, json; print json.load(sys.stdin)['clusterMetrics']['totalNodes']"`

# functions
#########################################################################################
usage() {
  echo "Usage:"
  echo $'\t' "$0 <Example folder> <BED folder> <Reference Version> <Contig Style> <Output Folder> "
  echo "Parameters:"
  echo $'\t' "<Example folder>: the output folder of make_examples"
  echo $'\t' "<BED folder>: the bed file for Adaptive Data Parallelization (ADP)"
  echo $'\t' "<Reference Version>: [ 19 | 38 ]"
  echo $'\t' "<Contig Style>: [ HG | GRCH ]"
  echo $'\t' "<Output Folder>: the output folder on HDFS"
  echo "Examples: "
  echo $'\t' "$0 output_HG002/examples /bed/19/contiguous_unmasked_regions_156_parts 19 GRCH output_HG002/variants"
  return
}

print_time () {
  now=$(date +%s)
  diff=$(($now - $1))
  str_diff=`date +%H:%M:%S -ud @${diff}`
  echo ${str_diff}
}

# argument check
#########################################################################################
if [[ $# -ne 5 ]]; then
  echo "[ERROR] Illegal number of parameters (Expected: 5, Actual: $#)"
  usage $0
  exit -1
fi

T0=$(date +%s)
# Cluster : n1_highmem_16 x 4
# num-executors | executor-cores | executor-memory | containers |  Memory   | vCores  |   Time   |
# ------------- | -------------- | --------------- | ---------- | --------- | ------- | -------- |
#       78      |        2       |     1g(8g)      |            |      G    |         | 02:00:32 |
#       31      |        2       |     1g(8g)      |            |      G    |         | 02:00:32 |

${spark} \
  --master yarn \
  --deploy-mode cluster \
  --name call_variants \
  --class net.vartotal.piper.cli.PiperMain \
  --num-executors $(( ($num_vcores / $executor_vcores) - 1 )) \
  --driver-memory 1g \
  --driver-cores 1 \
  --executor-memory 1g \
  --executor-cores ${executor_vcores} \
  --queue default \
  --conf spark.executor.extraJavaOptions=-XX:+UseG1GC \
  --conf spark.dynamicAllocation.minExecutors=1 \
  --conf spark.serializer=org.apache.spark.serializer.KryoSerializer \
  --conf spark.kryo.registrator=net.vartotal.piper.serialization.ADAMKryoRegistrator \
  --conf spark.speculation=true \
  --conf spark.hadoop.validateOutputSpecs=false \
  --conf spark.yarn.executor.memoryOverhead=8g \
  /usr/local/seqslab/PiedPiper/target/PiedPiper.jar \
  bam2vcf \
      --caller-type call_variants \
      --piper-script /usr/local/seqslab/SeqPiper/script/Bam2VcfPiperDeepVariantCV.py \
      --bam-input-path ${make_example_out} \
      --vcf-output-path ${call_variants_out} \
      --bam-partition-bed-path ${bed_path} \
      --reference-version ${ref_version} \
      --workflow-type 1 \
      --is-pcr-free 0 \
      --extra-params '' \
      --reference-system ${contig_style} \
      --platform-type illumina \
      --java-mem-in-mb 5120


if [[ $? != 0 ]]; then
  echo "########################################################################################"
  echo
  echo "[ERROR] call_variants failed: Please go to Hadoop Cluster Portal for more detail"
  echo
  echo "########################################################################################"
  exit -1
else
  str_time=$( print_time ${T0} )
  echo "########################################################################################"
  echo
  echo "[INFO] call_variants completed: " ${str_time}
  echo
  echo "########################################################################################"
fi
