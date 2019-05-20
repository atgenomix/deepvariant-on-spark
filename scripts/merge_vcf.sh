#!/usr/bin/env bash
# arguments
#########################################################################################
finalfile=$1
postprocess_variants_out=$2

hadoop fs -text ${postprocess_variants_out}/000.vcf.gz | grep ^# >> head.vcf
hadoop fs -text ${postprocess_variants_out}/*.vcf.gz | grep -v ^# | grep -w "PASS" >> merge-pass.vcf
cat head.vcf merge-pass.vcf > merge-all.vcf
bgzip merge-all.vcf
bcftools norm -D merge-all.vcf.gz -O z -o ${finalfile}.vcf.gz

#########################################################################################
