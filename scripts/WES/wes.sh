#!/usr/bin/env bash

# arguments
#########################################################################################
input_bam=$1
ref_version=$2
contig_style=$3
target_interval=$4
output_folder=$5
gvcf_flag=$6

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
exom_path=/seqslab/system/target_interval/${ref_version}/${target_interval}

# functions
#########################################################################################
usage() {
  echo "Usage:"
  echo $'\t' "$0 <Input BAM> <Reference Version> <Contig Style> <Exom Kit> <Output Folder> [GVCF]"
  echo "Parameters:"
  echo $'\t' "<Input BAM>: the input bam file from Google Strorage or HDFS"
  echo $'\t' "<Reference Version>: [ 19 | 38 ]"
  echo $'\t' "<Contig Style>: [ HG | GRCH ]"
  echo $'\t' "<Exom Kit>
  echo $'\t' "<Output Folder>: the output folder on HDFS"
  echo $'\t' "GVCF: the gvcf will be generated if enabled"
  echo "Examples: "
  echo $'\t' "$0 gs://seqslab-deepvariant/case-study/input/data/HG002_NIST_150bp_50x.bam 19 GRCH /output_HG002 "
  echo $'\t' "$0 gs://seqslab-deepvariant/case-study/input/data/HG002_NIST_150bp_50x.bam 19 GRCH /output_HG002 GVCF"
  return
}

print_time () {
  diff=$(($3 - $2))
  str_diff=`date +%H:%M:%S -ud @${diff}`
  echo $1 $'\t' $str_diff
}

# argument check
#########################################################################################
if [[ $# -ne 5 && $# -ne 6 ]]; then
  echo "[ERROR] Illegal number of parameters (Expected: 5 or 6, Actual: $#)"
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

hadoop fs -ls ${exom_path}

if [[ $? != 0 ]]; then
  echo "[ERROR]: unsupported exom kit - ${target_interval}"
  usage $0
  exit -4
fi

gvcf_out=""
if [[ $# -eq 6 ]]; then
  gvcf_out='hdfs:///$output_folder/gvcf'
fi

# main
##########################################################################################
T0=$(date +%s)
# transform_data
bash ${dirname}/transform_data.sh ${input_bam} ${alignment_parquet}

if [[ $? != 0 ]]; then
    exit -1
fi

T1=$(date +%s)
##########################################################################################
# select_bam
bash ${dirname}/select_bam.sh ${alignment_parquet} ${ref_version} ${alignment_bam}

if [[ $? != 0 ]]; then
  print_time "transform_data" ${T0} ${T1}
  exit -1
fi

T2=$(date +%s)

##########################################################################################
# make_examples
bash ${dirname}/make_examples.sh ${alignment_bam} ${bed_path} ${ref_version} ${contig_style} ${target_interval} ${make_examples_out}

if [[ $? != 0 ]]; then
  print_time "transform_data" ${T0} ${T1}
  print_time "select_bam" ${T1} ${T2}
  exit -1
fi

T3=$(date +%s)


##########################################################################################
# call_variants
bash ${dirname}/call_variants.sh ${make_examples_out} ${bed_path} ${ref_version} ${contig_style} ${target_interval} ${call_variants_out}

if [[ $? != 0 ]]; then
  print_time "transform_data" ${T0} ${T1}
  print_time "select_bam" ${T1} ${T2}
  print_time "make_examples" ${T2} ${T3}
  exit -1
fi

T4=$(date +%s)

##########################################################################################
# postprocess_variants
bash ${dirname}/postprocess_variants.sh ${make_examples_out} ${bed_path} ${ref_version} ${contig_style} ${target_interval} ${call_variants_out} ${postprocess_variants_out} ${gvcf_out}

if [[ $? != 0 ]]; then
  print_time "transform_data" ${T0} ${T1}
  print_time "select_bam" ${T1} ${T2}
  print_time "make_examples" ${T2} ${T3}
  print_time "call_variants" ${T3} ${T4}
  exit -1
fi

T5=$(date +%s)

#########################################################################################
# merge_vcf
bash ${dirname}/merge_vcf.sh ${output_folder} ${postprocess_variants_out}

if [[ $? != 0 ]]; then
  print_time "transform_data" ${T0} ${T1}
  print_time "select_bam" ${T1} ${T2}
  print_time "make_examples" ${T2} ${T3}
  print_time "call_variants" ${T3} ${T4}
  print_time "postprocess_variants" ${T4} ${T5}
  exit -1
fi

T6=$(date +%s)
print_time "transform_data" ${T0} ${T1}
print_time "select_bam" ${T1} ${T2}
print_time "make_examples" ${T2} ${T3}
print_time "call_variants" ${T3} ${T4}
print_time "postprocess_variants" ${T4} ${T5}
print_time "merge_vcf" ${T5} ${T6}

exit 0

#########################################################################################
