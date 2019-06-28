#!/usr/bin/env bash

# arguments
#########################################################################################
alignment_parquet=$1
ref_version=$2
alignment_bam=$3

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
  echo $'\t' "$0 <Alignment Folder> <Reference Version> <Output Folder> "
  echo "Parameters:"
  echo $'\t' "<Alignment Folder>: the output folder of transform_data.sh"
  echo $'\t' "<Reference Version>: [ 19 | 38 ]"
  echo $'\t' "<Output Folder>: the output folder on HDFS"
  echo "Examples: "
  echo $'\t' "$0 output_HG002/alignment.parquet 19 GRCH output_HG002/alignment.bam"
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
if [[ $# -ne 3 ]]; then
  echo "[ERROR] Illegal number of parameters (Expected: 3, Actual: $#)"
  usage $0
  exit -1
fi

if [[ ${ref_version} == "38" ]]; then
    partition_array=(
    "-l 000=chr1:0-248956422 -l 001=chr2:0-242193529 -l 002=chr3:0-198295559 \
  -l 003=chr4:0-190214555  -l 004=chr5:0-181538259  -l 005=chr6:0-170805979 \
  -l 006=chr7:0-159345973  -l 007=chr8:0-145138636  -l 008=chr9:0-138394717 \
  -l 009=chr10:0-133797422  -l 010=chr11:0-135086622  -l 011=chr12:0-133275309 \
  -l 012=chr13:0-114364328 -l 013=chr14:0-107043718 -l 014=chr15:0-101991189 \
  -l 015=chr16:0-90338345 -l 016=chr17:0-83257441 -l 017=chr18:0-80373285 \
  -l 018=chr19:0-58617616 -l 019=chr20:0-64444167 -l 020=chr21:0-46709983 \
  -l 021=chr22:0-50818468  -l 022=chrX:0-156040895  -l 023=chrY:0-57227415"
    )

elif [[ ${ref_version} == "19" ]]; then
    partition_array=(
    "-l 000=chr1:0-249250621 -l 001=chr2:0-243199373 -l 002=chr3:0-198022430 \
  -l 003=chr4:0-191154276 -l 004=chr5:0-180915260 -l 005=chr6:0-171115067 \
  -l 006=chr7:0-159138663 -l 007=chr8:0-146364022 -l 008=chr9:0-141213431 \
  -l 009=chr10:0-135534747 -l 010=chr11:0-135006516 -l 011=chr12:0-133851895 \
  -l 012=chr13:0-115169878 -l 013=chr14:0-107349540 -l 014=chr15:0-102531392 \
  -l 015=chr16:0-90354753 -l 016=chr17:0-81195210 -l 017=chr18:0-78077248 \
  -l 018=chr19:0-59128983 -l 019=chr20:0-63025520 -l 020=chr21:0-48129895 \
  -l 021=chr22:0-51304566 -l 022=chrX:0-155270560 -l 023=chrY:0-59373566" 
    )
fi

T0=$(date +%s)
# Cluster : n1_highmem_16 x 4
# num-executors | executor-cores | executor-memory | containers |  Memory   | vCores  |   Time   |
# ------------- | -------------- | --------------- | ---------- | --------- | ------- | -------- |
#        5      |        2       |         7g      |     30     |   220G    |    55   | 00:19:32 |
#        5      |        2       |        10g      |     30     |   285G    |    55   | 00:18:51 |
#        7      |        2       |         7g      |     33     |   234G    |    61   | 00:18:09*|
#        7      |        2       |        10g      |     33     |   318G    |   61(2) | 00:18:28 |
#        8      |        3       |        15g      |     11     |   112G    |    23   |   -----  |
#       12      |        2       |        10g      |     33     |   318G    |    61   | 00:17:51 |

pids=""

for i in ${!partition_array[@]};
do
  # echo ${i} --- ${partition_array[${i}]}
  ${spark} \
  --master yarn \
  --deploy-mode cluster \
  --class net.vartotal.piper.cli.PiperMain \
  --name SELECT_BAM-${i} \
  --driver-cores 1 \
  --driver-memory 1g \
  --num-executors $(( ${num_vcores} / ${executor_vcores} / 5 )) \
  --executor-cores ${executor_vcores} \
  --executor-memory 7g \
  --conf spark.hadoop.validateOutputSpecs=false \
  --conf spark.hadoop.dfs.replication=1 \
  --conf spark.dynamicAllocation.enabled=false \
  --conf spark.serializer=org.apache.spark.serializer.KryoSerializer \
  --conf spark.kryo.registrator=org.bdgenomics.adam.serialization.ADAMKryoRegistrator \
  --conf spark.executor.extraClassPath=/usr/local/seqslab/PiedPiper/target/PiedPiper.jar \
  /usr/local/seqslab/PiedPiper/target/PiedPiper.jar \
  newPosBinSelector \
      -i ${alignment_parquet} \
      -o ${alignment_bam} \
      -f bam \
      ${partition_array[${i}]} &

  pids+=" $!"
done

for p in ${pids}; do
  if wait ${p}; then
    str_time=$( print_time ${T0} )
    echo "[INFO] select_bam ${p} completed: " ${str_time}
  else
    echo "########################################################################################"
    echo
    echo "[ERROR] select_bam ${p} failed: Please go to Hadoop Cluster Portal for more detail"
    echo
    echo "########################################################################################"
    exit -1
  fi
done
