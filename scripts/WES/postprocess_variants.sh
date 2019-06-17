#!/usr/bin/env bash

# arguments
#########################################################################################
make_examples_out=$1
bed_path=$2
ref_version=$3
contig_style=$4
target_interval=$5
call_variants_out=$6
postprocess_variants_out=$7
gvcf_out=$8

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
  echo $'\t' "$0 <Example folder> <BED folder> <Reference Version> <Contig Style> <Exom Kit> <Variant Folder> <Output Folder> <GVCF Output Folder>"
  echo "Parameters:"
  echo $'\t' "<Example folder>: the output folder of make_examples"
  echo $'\t' "<BED folder>: the bed file for Adaptive Data Parallelization (ADP)"
  echo $'\t' "<Reference Version>: [ 19 | 38 ]"
  echo $'\t' "<Contig Style>: [ HG | GRCH ]"
  echo $'\t' "<Exom Kit>"
  echo $'\t' "<Variant folder>: the output folder of call_variants"
  echo $'\t' "<Output Folder>: the output folder on HDFS"
  echo $'\t' "<GVCF Output FOlder>: the gvcf output folder on HDFS"
  echo "Examples: "
  echo $'\t' "$0 /output_HG002/examples /bed/19/contiguous_unmasked_regions_156_parts 19 GRCH /output_HG002/variants /output_HG002/vcf"
  echo $'\t' "$0 /output_HG002/examples /bed/19/contiguous_unmasked_regions_156_parts 19 GRCH /output_HG002/variants /output_HG002/vcf /output_HG002/gvcf"
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
if [[ $# -ne 7 && $# -ne 8 ]]; then
  echo "[ERROR] Illegal number of parameters (Expected: 7 or 8, Actual: $#)"
  usage $0
  exit -1
fi

extra_params=" \\\" \\\" "

if [[ $# -eq 7 ]]; then
  extra_params="\\\" --gvcf_outfile ${gvcf_out} \\\" "
fi

T0=$(date +%s)
# Cluster : n1_highmem_16 x 4
# num-executors | executor-cores | executor-memory | containers |  Memory   | vCores  |   Time   |
# ------------- | -------------- | --------------- | ---------- | --------- | ------- | -------- |
#       78      |        2       |     1g(8g)      |            |      G    |         |     --   |
#       31      |        2       |     1g(7g)      |     32     |   250G    |    63   | 00:04:15 |

${spark} \
  --master yarn \
  --deploy-mode cluster \
  --name POSTPROCESS_VARIANTS \
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
  --conf spark.yarn.executor.memoryOverhead=7g \
  /usr/local/seqslab/PiedPiper/target/PiedPiper.jar \
  bam2vcf \
      --caller-type postprocess_variants \
      --piper-script /usr/local/seqslab/SeqPiper/script/Bam2VcfPiperDeepVariantPP.py \
      --bam-input-path ${make_examples_out} \
      --normal-bam-input-path ${call_variants_out} \
      --vcf-output-path ${postprocess_variants_out} \
      --bam-partition-bed-path ${bed_path} \
      --reference-version ${ref_version} \
      --workflow-type 2 \
      --is-pcr-free 0 \
      --extra-params ${extra_params} \
      --reference-system ${contig_style} \
      --platform-type illumina \
      --java-mem-in-mb 5120 \
      --target-interval-path  /seqslab/system/target_interval/${ref_version}/${target_interval}


if [[ $? != 0 ]]; then
  echo "########################################################################################"
  echo
  echo "[ERROR] postprocess_variants failed: Please go to Hadoop Cluster Portal for more detail"
  echo
  echo "########################################################################################"
  exit -1
else
  str_time=$( print_time ${T0} )
  echo "########################################################################################"
  echo
  echo "[INFO] postprocess_variants completed: " ${str_time}
  echo
  echo "########################################################################################"
fi
