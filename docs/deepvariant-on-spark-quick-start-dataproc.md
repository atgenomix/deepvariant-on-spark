# DeepVariant-on-Spark (DOS) Quick Start on Google Cloud

This is an explanation of how to launch DeepVariant-on-Spark in Google
Cloud.

## Background

Google Cloud Dataproc (Cloud Dataproc) is a cloud-based managed Spark
and Hadoop service offered on Google Cloud Platform.

## Preliminaries
To access DataProc, plese install `gsutil` first. You can go to
[Google Cloud](https://cloud.google.com/storage/docs/gsutil_install) for
installation guide.

## Launch Cluster

```
gcloud beta dataproc clusters create my-dos \
 --subnet default --zone us-west1-b \
 --image-version 1.2.59-deb9 \
 --initialization-actions gs://seqslab-deepvariant/scripts/initialization-on-dataproc.sh \
 --initialization-action-timeout 20m
```

## Delete Cluster

```
gcloud beta dataproc clusters delete my-dos
```

## Initialize DeepVariant-on-Spark (DOS)

DeepVariant-on-Spark leverage Ansible to deploy SeqPiper and related
packages to DataProc Cluster. For password-less deployment, your SSH key
should be added by using `ssh-add`. When the cluster has been launched
completely, you can login the terminal of the master via Google Cloud
Platform or the following command:

```
ssh-add -K <your SSH Key>
gcloud compute ssh --ssh-flag="-A" my-dos-m --zone="us-west1-b"
```

### Deploy SeqPiper and related packages

DeepVariant-on-Spark leverages `SeqPiper`, a wrapper of Spark `Pipe()`,
to wrap DeepVariant in Spark. Please clone DeepVaraint-on-Spark github
repo. and use Ansible, IT automation tools, to install SeqPiper and
related packages followed by the following commands:

```
git clone https://github.com/atgenomix/deepvariant-on-spark.git
cd deepvariant-on-spark/ansible
python host_gen.py
ansible-playbook -i hosts prepare_env.yml
```

Then, DeepVariant-on-Spark will be installed automatically by Ansible. It
will take 10 or more minutes to deploy all of necessary packages to the
entire cluster. If successful, all of deployment has no failure and you
will see the log like:
```
... (skipped) ...

PLAY RECAP *********************************************************************
my-dos-m                   : ok=21   changed=13   unreachable=0    failed=0
my-dos-w-0                 : ok=26   changed=22   unreachable=0    failed=0
my-dos-w-1                 : ok=26   changed=22   unreachable=0    failed=0
```

**Congradulates! Let's start to run
[the first WGS sample](docs/wgs-case-study.md).**

NOTE: If any failure is occurred, please refer to the following session
to find the root cause. If not fixed, please submit an issue to [our
github repo](https://github.com/atgenomix/deepvariant-on-spark/issues/new)

## Check Environment

DeepVariant will be installed into each worker node. You can login the
terminal of the first worker via Google Cloud Platform or the following
command:

```
gcloud compute ssh --ssh-flag="-A" my-dos-w-0 --zone="us-west1-b"
```

### Verify DeepVariant Package

DeepVariant will be installed in /usr/local/seqslab/deepvariant, so you can check
whether the following subfolders are existed in the folder or not.
```
user@my-dos-w-0:~$ ls -al /usr/local/seqslab/deepvariant/
drwxr-sr-x  2 root staff 4096 Jan  4 05:50 DeepVariant-inception_v3-0.7.0+data-wes_standard
drwxr-sr-x  2 root staff 4096 Jan  4 05:50 DeepVariant-inception_v3-0.7.0+data-wgs_standard
```

The models of DeepVariant comprises WGS and WES

```
user@my-dos-w-0:~$ ls -al /usr/local/seqslab/deepvariant/DeepVariant-inception_v3-0.7.0+data-wgs_standard
-rw-r--r--  1 root staff 348681272 Jan  4 05:50 model.ckpt.data-00000-of-00001
-rw-r--r--  1 root staff     18496 Jan  4 05:50 model.ckpt.index
-rw-r--r--  1 root staff  31106596 Jan  4 05:50 model.ckpt.meta
```

```
user@my-dos-w-0:~$ ls -al /usr/local/seqslab/deepvariant/DeepVariant-inception_v3-0.7.0+data-wes_standard
-rw-r--r--  1 root staff 348681272 Jan  4 05:50 model.ckpt.data-00000-of-00001
-rw-r--r--  1 root staff     18473 Jan  4 05:50 model.ckpt.index
-rw-r--r--  1 root staff  31118992 Jan  4 05:50 model.ckpt.meta
```

All executables are ready in `/usr/local/seqslab/deepvariant/bazel-bin/deepvariant/`

```
user@my-dos-w-0:~$ ls -al /usr/local/seqslab/deepvariant/bazel-bin/deepvariant/
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
MODEL="/usr/local/seqslab/deepvariant/${MODEL_NAME}/model.ckpt"
CALL_VARIANTS_OUTPUT="${OUTPUT_DIR}/call_variants_output.tfrecord.gz"
FINAL_OUTPUT_VCF="${OUTPUT_DIR}/output.vcf.gz"

/usr/local/seqslab/deepvariant/bazel-bin/deepvariant/make_examples \
  --mode calling \
  --ref "${REF}" \
  --reads "${BAM}" \
  --regions "chr20:10,000,000-10,010,000" \
  --examples "${OUTPUT_DIR}/examples.tfrecord.gz"

/usr/local/seqslab/deepvariant/bazel-bin/deepvariant/call_variants \
  --outfile "${CALL_VARIANTS_OUTPUT}" \
  --examples "${OUTPUT_DIR}/examples.tfrecord.gz" \
  --execution_hardware="seqslab" \
  --checkpoint "${MODEL}"

/usr/local/seqslab/deepvariant/bazel-bin/deepvariant/postprocess_variants \
  --ref "${REF}" \
  --infile "${CALL_VARIANTS_OUTPUT}" \
  --outfile "${FINAL_OUTPUT_VCF}"

```

For evaluation, please check ${OUTPUT_DIR} and verify those output files
and their size.

```
user@my-dos-w-0:~$ ls -al ${OUTPUT_DIR}
-rw-r--r-- 1 user user   4132 Jan  4 06:57 call_variants_output.tfrecord.gz
-rw-r--r-- 1 user user 532000 Jan  4 06:56 examples.tfrecord.gz
-rw-r--r-- 1 user user 154742 Jan  4 06:56 examples.tfrecord.gz.run_info.pbtxt
-rw-r--r-- 1 user user   2207 Jan  4 06:57 output.vcf.gz
```

## Launch GPU Environment

If you would like to test GPU environment, you can launch a GPU cluster
by the following command:

```
gcloud beta dataproc clusters create my-dos \
 --subnet default --zone us-west1-b \
 --worker-accelerator type=nvidia-tesla-p100,count=1 \
 --image-version 1.2.59-deb9 \
 --initialization-actions gs://seqslab-deepvariant/scripts/initialization-on-dataproc.sh \
 --initialization-action-timeout 20m
```

`call_variants` is the only step of DeepVariant which is able to be
benefited by GPU. Using the patched DeepVariant version, we can specify
the memory resource of GPU for each DeepVariant process, like

```
/usr/local/seqslab/deepvariant/bazel-bin/deepvariant/call_variants \
  --outfile "${CALL_VARIANTS_OUTPUT}" \
  --examples "${OUTPUT_DIR}/examples.tfrecord.gz" \
  --execution_hardware="seqslab_gpu" \
  --percentage_gpu_memory=16 \
  --checkpoint "${MODEL}"
```

