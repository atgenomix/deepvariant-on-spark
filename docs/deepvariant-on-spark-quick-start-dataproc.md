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
For password-less deployment, your SSH key is required. Please refer to
[this link](https://cloud.google.com/compute/docs/instances/adding-removing-ssh-keys)
for acquiring your SSH Key.

## Launch Cluster

```
gcloud beta dataproc clusters create my-dos \
 --subnet default --zone us-west1-b \
 --num-workers 2 --worker-machine-type n1-highmem-16 \
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
(i.e. ~/.ssh/google_compute_engine) should be added by using `ssh-add`
first. When the cluster has been launched completely, you can login the
terminal of the master via Google Cloud Platform or the following
command:

```
ssh-add -K ~/.ssh/google_compute_engine
gcloud compute ssh --ssh-flag="-A" my-dos-m --zone="us-west1-b"
```

*Note*: if `ssh-add` is failed and the error message is like "Error
connecting to agent: No such file or directory", please use the
following command first.

```
ssh-agent bash
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

Please refer to [Cluster Operation Portal](docs/trobuleshooting.md#how-to-monitor-the-progress-of-the-pipeline-)
to monitor the healthy status of YARN and HDFS.

## A Quick Test Case

To evaluate the deployment, the following command is able to run the
whole pipeline by using a small sample.

```
bash ./deepvariant-on-spark/scripts/run.sh gs://deepvariant/case-study-testdata/NA12878_sliced.bam 19 GRCH output
```

Then, you will have the following log if successful.

```
19/01/17 07:01:20 INFO com.google.cloud.hadoop.fs.gcs.GoogleHadoopFileSystemBase: GHFS version: 1.6.10-hadoop2
19/01/17 07:01:21 INFO org.apache.hadoop.yarn.client.RMProxy: Connecting to ResourceManager at my-dos-m/10.138.1.18:8032

... (skipped) ...

19/01/17 07:10:32 INFO com.google.cloud.hadoop.fs.gcs.GoogleHadoopFileSystemBase: GHFS version: 1.6.10-hadoop2
19/01/17 07:10:33 INFO org.apache.hadoop.yarn.client.RMProxy: Connecting to ResourceManager at my-dos-m/10.138.1.18:8032
19/01/17 07:10:35 INFO org.apache.hadoop.yarn.client.api.impl.YarnClientImpl: Submitted application application_1547707864423_0009
########################################################################################

[INFO] postprocess_variants completed:  00:02:05

########################################################################################
transform_data 	 00:01:01
select_bam 	 00:01:00
make_examples 	 00:05:13
call_variants 	 00:01:59
postprocess_variants 	 00:02:05
```

Also, you can check the output files.

```
user@my-dos-m:~$ hadoop fs -du -h /output
5.6 M   /output/alignment.bam
36.2 M  /output/alignment.parquet
1.9 M   /output/examples
13.3 K  /output/variants
6.8 K   /output/vcf
```

**Congradulates! Let's start to run
[the first WGS sample](docs/wgs-case-study.md).**

NOTE: If any failure is occurred, please refer to [the trobuleshooting
session](docs/trobuleshooting.md) to find the root cause. If not fixed,
please submit an issue to [our github repo](https://github.com/atgenomix/deepvariant-on-spark/issues/new)

## A simple test case

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

Before launching a Dataproc with GPU hardware, you should check whether
you have enough quota for your use case. As your use of Google Cloud
Platform expands over time, your quotas may increase accordingly. If you
expect a notable upcoming increase in usage, you can proactively
[request quota](https://cloud.google.com/compute/quotas#request_quotas)
adjustments from the Quotas page in the GCP Console.

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

