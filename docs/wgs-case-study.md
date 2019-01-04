# DeepVariant-on-Spark WGS case study

In this case study we describe applying DeepVariant-on-Spark to a real
WGS sample.

## Background

We use the same WGS data from DeepVariant for demonstration.

NOTE: This case study demonstrates an example of how to run
DeepVariant-on-Spark end-to-end pipeline on Google DataProc. This might
not be the fastest or cheapest configuration for your needs.

## Launch CPU Cluster

In this example, there are 5 worker nodes launched and each node has 16
vcores with 104 GB memory.

```
gcloud beta dataproc clusters create my-deepvariant-on-spark \
  --subnet default --zone us-west1-b \
  --master-machine-type n1-highmem-8 --master-boot-disk-size 1024 \
  --num-workers 5 --worker-machine-type n1-highmem-16 \
  --worker-boot-disk-size 384 \
  --num-worker-local-ssds 1 --image-version 1.3-deb9  \
  --initialization-actions gs://seqslab-deepvariant/scripts/initialization-on-dataproc.sh  \
  --initialization-action-timeout 20m
```


## Install SeqPiper and related packages

DeepVariant-on-Spark leverage SeqsPiper to wrap DeepVariant into

## Execute DeepVariant on Spark

### Preliminaries

Set a number of shell variables and create local directory structure, to
make what follows easier to read and operate.

```
BASE="${HOME}/case-study"
BUCKET="gs://deepvariant"
BIN_VERSION="0.7.0"

DATA_BUCKET="${BUCKET}/case-study-testdata"

INPUT_DIR="${BASE}/input"
DATA_DIR="${INPUT_DIR}/data"
BAM="${DATA_DIR}/HG002_NIST_150bp_50x.bam"
TRUTH_VCF="${DATA_DIR}/HG002_GRCh37_GIAB_highconf_CG-IllFB-IllGATKHC-Ion-10X-SOLID_CHROM1-22_v.3.3.2_highconf_triophased.vcf.gz"
TRUTH_BED="${DATA_DIR}/HG002_GRCh37_GIAB_highconf_CG-IllFB-IllGATKHC-Ion-10X-SOLID_CHROM1-22_v.3.3.2_highconf_noincons

OUTPUT_DIR="${BASE}/output"
OUTPUT_VCF="${OUTPUT_DIR}/HG002.output.vcf.gz"
OUTPUT_GVCF="${OUTPUT_DIR}/HG002.output.g.vcf.gz"
LOG_DIR="${OUTPUT_DIR}/logs"

mkdir -p "${OUTPUT_DIR}"
mkdir -p "${DATA_DIR}"
mkdir -p "${LOG_DIR}"
```

### Prepare data

```
time gsutil -m cp -r "${DATA_BUCKET}/HG002_NIST_150bp_50x.bam" "${DATA_DIR}"
```

It took us about 15min to copy the files.

### Result

## Delete Cluster

```
gcloud beta dataproc clusters delete my-deepvariant-on-spark
```
