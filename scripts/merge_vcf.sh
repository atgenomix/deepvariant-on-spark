#!/usr/bin/env bash
# arguments
#########################################################################################
finalfile=$1
postprocess_variants_out=$2

hadoop fs -text ${postprocess_variants_out}/000.vcf.gz | grep ^# > merge-all.vcf
hadoop fs -text ${postprocess_variants_out}/*.vcf.gz | grep -v ^# | grep -w "PASS" >> merge-all.vcf
bgzip merge-all.vcf
bcftools norm -d any --no-version merge-all.vcf.gz -O z -o ${finalfile}.vcf.gz
rm -rf merge-all.vcf.gz

#########################################################################################
