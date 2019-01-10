#!/usr/bin/env bash

# arguments
#########################################################################################
input_bam=$1
ref_version=$2
contig_style=$3
output_folder=$4

# constant and variables
#########################################################################################
SUCCESS='SUCCESS'
FAIL='FAIL'
spark=/usr/bin/spark-submit
alignment_parquet=hdfs:///$output_folder/alignment.parquet
alignment_bam=hdfs:///$output_folder/alignment.bam
make_example_dir=hdfs:///$output_folder/examples
call_variants_dir=hdfs:///$output_folder/variant
postprocess_variants_dir=hdfs:///$output_folder/vcf
bed_path=hdfs:///bed/${ref_version}/contiguous_unmasked_regions_156_parts
executor_vcores=2
num_vcores=`curl http://localhost:8088/ws/v1/cluster/metrics | \
            python -c "import sys, json; print json.load(sys.stdin)['clusterMetrics']['totalVirtualCores']"`
num_nodes=`curl http://localhost:8088/ws/v1/cluster/metrics | \
            python -c "import sys, json; print json.load(sys.stdin)['clusterMetrics']['totalNodes']"`
dirname=`dirname $0`

# functions
#########################################################################################
usage() {
  echo "Usage:"
  echo $'\t' "$0 <Input BAM> <Output Folder> <Reference Version> <Contig Style>"
  echo "Parameters:"
  echo $'\t' "<Input BAM>: the input bam file from Google Strorage or HDFS"
  echo $'\t' "<Output Folder>: the output folder on HDFS"
  echo $'\t' "<Reference Version>: [ 19 | 38 ]"
  echo $'\t' "<Contig Style>: [ HG | GRCH ]"
  echo "Examples: "
  echo $'\t' "$0 gs://seqslab-deepvariant/case-study/input/data/HG002_NIST_150bp_50x.bam output 19 GRCH"
  return
}

print_time () {
  diff=$(($3 - $2))
  str_diff=`date +%H:%M:%S -ud @${diff}`
  echo $1 $'\t' $str_diff
}

# argument check
#########################################################################################
if [[ $# -ne 4 ]]; then
  echo "[ERROR] Illegal number of parameters (Expected: 4, Actual: $#)"
  usage $0
  exit -1
fi

if [[ ${ref_version} != "19" && ${ref_version} != "38" ]]; then
  echo "[ERROR]: unsupported ref version - ${ref_version}"
  usage $0
  exit -2
fi

if [[ ${contig_style} != "HG" && ${contig_style} != "GRCH" ]]; then
  echo "[ERROR]: unsupported contig style -- ${contig_style}"
  usage $0
  exit -3
fi

# main
##########################################################################################
T0=$(date +%s)
# transform_data
${dirname}\transform_data.sh ${input_bam} ${alignment_parquet}

if [[ $? != 0 ]]; then
    exit -1
fi

##########################################################################################
T1=$(date +%s)
# select_bam
${dirname}\select_bam.sh ${alignment_parquet}

if [[ $? != 0 ]]; then
    exit -1
fi

T2=$(date +%s)

pids=""

for i in ${!partition_array[@]};
do
  # echo ${i} --- ${partition_array[${i}]}
  ${spark} \
  --master yarn \
  --deploy-mode cluster \
  --class net.vartotal.piper.cli.PiperMain \
  --name SELECTOR-${i} \
  --driver-cores 1 \
  --driver-memory 1g \
  --num-executors 5 \
  --executor-cores 2 \
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
    echo "BamSelector Process ${p} success"
  else
    echo "###########################################################"
    echo
    echo "BamSelector Process ${p} fail"
    echo
    echo "###########################################################"
    exit -1

  fi
done

# make_examples
${spark} \
  --master yarn \
  --deploy-mode cluster \
  --name make_examples \
  --class net.vartotal.piper.cli.PiperMain \
  --num-executors 78 \
  --driver-memory 1g \
  --driver-cores 1 \
  --executor-memory 1g \
  --executor-cores 2 \
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
      --caller-type make_example \
      --piper-script /usr/local/seqslab/SeqPiper/script/Bam2VcfPiperDeepVariantME.py \
      --bam-input-path ${alignment_bam}/bam \
      --vcf-output-path ${make_example_dir} \
      --bam-partition-bed-path ${bed_path} \
      --reference-version ${ref_version} \
      --workflow-type 1 \
      --is-pcr-free 0 \
      --extra-params '' \
      --reference-system ${contig_style} \
      --platform-type illumina \
      --java-mem-in-mb 5120

if [[ $? != 0 ]]; then
    echo "###########################################################"
    echo
    echo "make_example failed"
    echo
    echo "###########################################################"
    exit -1
fi

${spark} \
  --master yarn \
  --deploy-mode cluster \
  --name call_variants \
  --class net.vartotal.piper.cli.PiperMain \
  --num-executors 78 \
  --driver-memory 1g \
  --driver-cores 1 \
  --executor-memory 1g \
  --executor-cores 2 \
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
      --bam-input-path ${make_example_dir} \
      --vcf-output-path ${call_variants_dir} \
      --bam-partition-bed-path ${bed_path} \
      --reference-version ${ref_version} \
      --workflow-type 1 \
      --is-pcr-free 0 \
      --extra-params '' \
      --reference-system ${contig_style} \
      --platform-type illumina \
      --java-mem-in-mb 5120

if [[ $? != 0 ]]; then
    echo "###########################################################"
    echo
    echo "call_variant failed"
    echo
    echo "###########################################################"
    exit -1
fi

${spark} \
  --master yarn \
  --deploy-mode cluster \
  --name postprocess_variants \
  --class net.vartotal.piper.cli.PiperMain \
  --num-executors 78 \
  --driver-memory 1g \
  --driver-cores 1 \
  --executor-memory 1g \
  --executor-cores 2 \
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
      --caller-type postprocess_variants \
      --piper-script /usr/local/seqslab/SeqPiper/script/Bam2VcfPiperDeepVariantPP.py \
      --bam-input-path ${make_example_dir} \
      --normal-bam-input-path ${call_variants_dir} \
      --vcf-output-path ${postprocess_variants_dir} \
      --bam-partition-bed-path ${bed_path} \
      --reference-version ${ref_version} \
      --workflow-type 1 \
      --is-pcr-free 0 \
      --extra-params '' \
      --reference-system ${contig_style} \
      --platform-type illumina \
      --java-mem-in-mb 5120

if [[ $? != 0 ]]; then
    echo "###########################################################"
    echo
    echo "postprocess_variant failed"
    echo
    echo "###########################################################"
    exit -1
fi

#python3 get_variants.py ${postprocess_variants_dir}
