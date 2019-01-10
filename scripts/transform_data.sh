#!/usr/bin/env bash

# arguments
#########################################################################################
input_bam=$1
alignment_parquet=$2

# constant & variables
#########################################################################################
spark=/usr/bin/spark-submit
alignment_parquet=hdfs:///$output_folder/alignment.parquet
executor_vcores=4
num_vcores=`curl http://localhost:8088/ws/v1/cluster/metrics | \
            python -c "import sys, json; print json.load(sys.stdin)['clusterMetrics']['totalVirtualCores']"`
num_nodes=`curl http://localhost:8088/ws/v1/cluster/metrics | \
            python -c "import sys, json; print json.load(sys.stdin)['clusterMetrics']['totalNodes']"`

# functions
#########################################################################################
usage() {
  echo "Usage:"
  echo $'\t' "$0 <Input BAM> <Output Folder> "
  echo "Parameters:"
  echo $'\t' "<Input BAM>: the input bam file from Google Strorage or HDFS"
  echo $'\t' "<Output Folder>: the output folder on HDFS"
  echo "Examples: "
  echo $'\t' "$0 gs://seqslab-deepvariant/case-study/input/data/HG002_NIST_150bp_50x.bam output_HG002/alignment.parquet"
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
if [[ $# -ne 2 ]]; then
  echo "[ERROR] Illegal number of parameters (Expected: 2, Actual: $#)"
  usage $0
  exit -1
fi

# main
##########################################################################################
T0=$(date +%s)
# num-executors | executor-cores | executor-memory | containers |  Memory   | vCores  |   Time   |
# ------------- | -------------- | --------------- | ---------- | --------- | ------- | -------- |
#       10      |        4       |        35g      |      9     |   280G    |    9    | 00:43:20 |
#        8      |        7       |        40g      |      9     |   358G    |   57    | 00:39:14 |
#       12      |        5       |        30g      |     13     |   398G    |   61    | 00:36:42 |
#       15      |        4       |        22g      |     16     |   378G    |   61    | 00:36:08*|
#       20      |        3       |        18g      |     20     | 382G(20G) |   58(3) |    --    |
#       20      |        3       |        16g      |     21     |   362G    |   61    | 00:36:42 |
#       31      |        2       |        10g      |     32     |   343G    |   63    |  failed  |
#       31      |        2       |        11g      |     29     | 366G(26g) |   57(4) |  failed  |
#       31      |        2       |        12g      |     29     |   394G    |   57    |    --    |

# adam
${spark} \
  --master yarn \
  --deploy-mode cluster \
  --name AtgxTransform \
  --class org.bdgenomics.adam.cli.ADAMMain \
  --num-executors $(($num_nodes * ($num_vcores / $executor_vcores) - 1))  \
  --driver-memory 2g \
  --driver-cores 1 \
  --executor-cores ${executor_vcores} \
  --executor-memory 22g \
  --queue default \
  --conf spark.hadoop.validateOutputSpecs=false \
  --conf spark.dynamicAllocation.enabled=false \
  --conf spark.dynamicAllocation.minExecutors=1 \
  --conf spark.executor.extraJavaOptions=-XX:+UseG1GC \
  --conf spark.serializer=org.apache.spark.serializer.KryoSerializer \
  --conf spark.kryo.registrator=org.bdgenomics.adam.serialization.ADAMKryoRegistrator \
  /usr/local/seqslab/adam/adam-assembly/target/adam.jar transformAlignments \
      ${input_bam} \
      ${alignment_parquet} \
      -force_load_bam -atgx_transform -parquet_compression_codec SNAPPY

if [[ $? != 0 ]]; then
  echo "########################################################################################"
  echo
  echo "[ERROR] transform_data failed: Please go to Hadoop Cluster Portal for more detail"
  echo
  echo "########################################################################################"
  exit -1
else
  str_time=$( print_time ${T0} )
  echo "########################################################################################"
  echo
  echo "[INFO] transform_data completed: " ${str_time}
  echo
  echo "########################################################################################"
fi
