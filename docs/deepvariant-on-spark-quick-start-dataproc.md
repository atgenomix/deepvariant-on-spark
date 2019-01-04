# DeepVariant-on-Spark Quick Start on Google Cloud

This is an explanation of how to launch DeepVariant-on-Spark in Google
Cloud.

## Background

Google Cloud Dataproc (Cloud Dataproc) is a cloud-based managed Spark
and Hadoop service offered on Google Cloud Platform.

## Launch Cluster

```
 gcloud beta dataproc clusters create my-deepvariant-on-spark \
 --subnet default --zone us-west1-b \
 --image-version 1.2.59-deb9 \
 --initialization-actions gs://seqslab-deepvariant/scripts/initialization-on-dataproc.sh \
 --initialization-action-timeout 20m
```

## Delete Cluster

```
gcloud beta dataproc clusters delete my-deepvariant-on-spark
```

## Check Environment

DeepVariant will be installed into each worker node. You can login the
terminal of the first worker via Google Cloud Platform or the following
command:

```
gcloud compute ssh --ssh-flag="-A" my-deepvariant-on-spark-w-0 --zone="us-west1-b"
```

### Verify DeepVariant Package

DeepVariant will be installed in /usr/local/deepvariant, so you can check
whether the following subfolders are existed in the folder or not.
```
user@my-deepvariant-on-spark-w-0:~$ ls -al /usr/local/deepvariant/
lrwxrwxrwx  1 root staff  121 Jan  4 05:43 bazel-bin -> /usr/local/.cache/bazel/_bazel_root/64dab1e556632dd3bc1768095a19236c/execroot/com_google_deepvariant/bazel-out/k8-opt/bin
drwxr-sr-x  2 root staff 4096 Jan  4 05:50 DeepVariant-inception_v3-0.7.0+data-wes_standard
drwxr-sr-x  2 root staff 4096 Jan  4 05:50 DeepVariant-inception_v3-0.7.0+data-wgs_standard
```

The models of DeepVariant comprises WGS and WES

```
user@my-deepvariant-on-spark-w-0:~$ ls -al /usr/local/deepvariant/DeepVariant-inception_v3-0.7.0+data-wgs_standard
-rw-r--r--  1 root staff 348681272 Jan  4 05:50 model.ckpt.data-00000-of-00001
-rw-r--r--  1 root staff     18496 Jan  4 05:50 model.ckpt.index
-rw-r--r--  1 root staff  31106596 Jan  4 05:50 model.ckpt.meta
```

```
user@my-deepvariant-on-spark-w-0:~$ ls -al /usr/local/deepvariant/DeepVariant-inception_v3-0.7.0+data-wes_standard
-rw-r--r--  1 root staff 348681272 Jan  4 05:50 model.ckpt.data-00000-of-00001
-rw-r--r--  1 root staff     18473 Jan  4 05:50 model.ckpt.index
-rw-r--r--  1 root staff  31118992 Jan  4 05:50 model.ckpt.meta
```

```
user@my-deepvariant-on-spark-w-0:~$ ls -al /usr/local/deepvariant/bazel-bin/deepvariant/
-r-xr-xr-x 1 root staff 5874931 Jan  4 05:50 call_variants
-r-xr-xr-x 1 root staff 9807273 Jan  4 05:50 make_examples
-r-xr-xr-x 1 root staff 7839862 Jan  4 05:50 postprocess_variants
```

If the above files are existed, DeepVariant is installed successfully.

### A simple test case

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
  --execution_hardware="seqslab" \
  --checkpoint "${MODEL}"

/usr/local/deepvariant/bazel-bin/deepvariant/postprocess_variants \
  --ref "${REF}" \
  --infile "${CALL_VARIANTS_OUTPUT}" \
  --outfile "${FINAL_OUTPUT_VCF}"

```

For evaluation, please check ${OUTPUT_DIR} and verify those output files
and their size.

```
user@my-deepvariant-on-spark-w-1:~$ ls -al ${OUTPUT_DIR}
-rw-r--r-- 1 user user   4132 Jan  4 06:57 call_variants_output.tfrecord.gz
-rw-r--r-- 1 user user 532000 Jan  4 06:56 examples.tfrecord.gz
-rw-r--r-- 1 user user 154742 Jan  4 06:56 examples.tfrecord.gz.run_info.pbtxt
-rw-r--r-- 1 user user   2207 Jan  4 06:57 output.vcf.gz
```
