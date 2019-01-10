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
make_examples_out=hdfs:///$output_folder/examples
call_variants_out=hdfs:///$output_folder/variants
postprocess_variants_out=hdfs:///$output_folder/vcf
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
  echo $'\t' "$0 <Input BAM> <Reference Version> <Contig Style> <Output Folder>"
  echo "Parameters:"
  echo $'\t' "<Input BAM>: the input bam file from Google Strorage or HDFS"
  echo $'\t' "<Reference Version>: [ 19 | 38 ]"
  echo $'\t' "<Contig Style>: [ HG | GRCH ]"
  echo $'\t' "<Output Folder>: the output folder on HDFS"
  echo "Examples: "
  echo $'\t' "$0 gs://seqslab-deepvariant/case-study/input/data/HG002_NIST_150bp_50x.bam 19 GRCH output_HG002 "
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
# bash ${dirname}/transform_data.sh ${input_bam} ${alignment_parquet}

if [[ $? != 0 ]]; then
    exit -1
fi

T1=$(date +%s)
print_time "transform_data" ${T0} ${T1}
##########################################################################################
# select_bam
# bash ${dirname}/select_bam.sh ${alignment_parquet} ${ref_version} ${alignment_bam}

if [[ $? != 0 ]]; then
    exit -1
fi

T2=$(date +%s)
print_time "select_bam" ${T1} ${T2}

##########################################################################################
# make_examples
# bash ${dirname}/make_examples.sh ${alignment_bam} ${bed_path} ${ref_version} ${contig_style} ${make_examples_out}

if [[ $? != 0 ]]; then
    exit -1
fi

T3=$(date +%s)
print_time "make_examples" ${T2} ${T3}


##########################################################################################
# make_examples
bash ${dirname}/call_variants.sh ${make_examples_out} ${bed_path} ${ref_version} ${contig_style} ${call_variants_out}

if [[ $? != 0 ]]; then
    exit -1
fi

T4=$(date +%s)
print_time "make_examples" ${T3} ${T4}

exit 0

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
      --bam-input-path ${make_examples_out} \
      --normal-bam-input-path ${call_variants_out} \
      --vcf-output-path ${postprocess_variants_out} \
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
