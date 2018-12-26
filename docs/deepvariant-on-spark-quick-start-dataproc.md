# DeepVariant-on-Spark Quick Start on Google Cloud

This is an explanation of how to launch DeepVariant-on-Spark in Google
Cloud.

## Background

Google Cloud Dataproc (Cloud Dataproc) is a cloud-based managed Spark
and Hadoop service offered on Google Cloud Platform.

## Launch Cluster

```
gcloud beta dataproc clusters create deepvariant-on-spark \
  --subnet default --zone us-west1-b \
  --master-machine-type n1-highmem-8 --master-boot-disk-size 1024 \
  --num-workers 5 --worker-machine-type n1-highmem-16 \
  --worker-boot-disk-size 384 \
  --worker-accelerator type=nvidia-tesla-p100,count=1 \
  --num-worker-local-ssds 1 --image-version 1.3-deb9  \
  --initialization-actions gs://seqslab-deepvariant/scripts/initialization-on-dataproc.sh  \
  --initialization-action-timeout 20m
```


## Delete Cluster

```
gcloud beta dataproc clusters delete deepvariant-on-spark
```

## Simple Test Case

Please login one of worker node and enter the following commands.

```
BUCKET="gs://deepvariant"
DATA_BUCKET="${BUCKET}/quickstart-testdata"
gsutil cp -R "${DATA_BUCKET}" .
REF=/home/${USER}/quickstart-testdata/ucsc.hg19.chr20.unittest.fasta
BAM=/home/${USER}/quickstart-testdata/NA12878_S1.chr20.10_10p1mb.bam
OUTPUT_DIR=/home/${USER}/quickstart-output
mkdir -p "${OUTPUT_DIR}"
BIN_VERSION="0.7.0"
MODEL_VERSION="0.7.0"
MODEL_NAME="DeepVariant-inception_v3-${MODEL_VERSION}+data-wgs_standard"
MODEL="/usr/local/deepvariant/${MODEL_NAME}/model.ckpt"
CALL_VARIANTS_OUTPUT="${OUTPUT_DIR}/call_variants_output.tfrecord.gz"
FINAL_OUTPUT_VCF="${OUTPUT_DIR}/output.vcf.gz"

/usr/local/deepvariant/bazel-bin/deepvariant/make_examples \
  --mode calling \
  --ref "${REF}" \
  --reads "${BAM}" \
  --regions "chr20:10,000,000-10,010,000" \
  --examples "${OUTPUT_DIR}/examples.tfrecord.gz"

/usr/local/deepvariant/bazel-bin/deepvariant/call_variants \
  --outfile "${CALL_VARIANTS_OUTPUT}" \
  --examples "${OUTPUT_DIR}/examples.tfrecord.gz" \
  --execution_hardware="seqslab_gpu" \
  --percentage_gpu_memory=16 \
  --checkpoint "${MODEL}"

/usr/local/deepvariant/bazel-bin/deepvariant/postprocess_variants \
  --ref "${REF}" \
  --infile "${CALL_VARIANTS_OUTPUT}" \
  --outfile "${FINAL_OUTPUT_VCF}"

```

For evaluation, please check ${OUTPUT_DIR} and verify those output files
and their size.

```
atgenomix@deepvariant-on-spark-w-1:~$ ls -al ${OUTPUT_DIR}
-rw-r--r-- 1     4123 Dec 26 08:54 call_variants_output.tfrecord.gz
-rw-r--r-- 1   531797 Dec 26 08:54 examples.tfrecord.gz
-rw-r--r-- 1   154744 Dec 26 08:54 examples.tfrecord.gz.run_info.pbtxt
-rw-r--r-- 1     2209 Dec 26 09:03 output.vcf.gz
```
