# DeepVariant-on-Spark WGS case study

In this case study we describe applying DeepVariant-on-Spark to a real
WGS sample.

## Background

We use the same WGS data from DeepVariant for demonstration.

NOTE: This case study demonstrates an example of how to run
DeepVariant-on-Spark end-to-end pipeline on Google DataProc. This might
not be the fastest or cheapest configuration for your needs.

## Launch CPU Cluster

In this example, there are 4 worker nodes launched and each node has 16
vcores with 104 GB memory.

```
gcloud beta dataproc clusters create my-dos \
  --subnet default --zone us-west1-b \
  --master-machine-type n1-highmem-8 --master-boot-disk-size 256 \
  --num-workers 4 --worker-machine-type n1-highmem-16 \
  --worker-boot-disk-size 384 \
  --num-worker-local-ssds 1 --image-version 1.2.59-deb9  \
  --initialization-actions gs://seqslab-deepvariant/scripts/initialization-on-dataproc.sh  \
  --initialization-action-timeout 20m \
  --properties=^--^capacity-scheduler:yarn.scheduler.capacity.resource-calculator=org.apache.hadoop.yarn.util.resource.DominantResourceCalculator--yarn:yarn.scheduler.maximum-allocation-mb=103424--yarn:yarn.nodemanager.resource.memory-mb=103424
```

After the cluster has been launched, please follow [the quick-start guide
for DataProc](/docs/deepvariant-on-spark-quick-start-dataproc.md#initialize-deepvariant-on-spark-dos)
to install DeeopVariant-on-Spark.

## Run a WGS sample

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
TRUTH_BED="${DATA_DIR}/HG002_GRCh37_GIAB_highconf_CG-IllFB-IllGATKHC-Ion-10X-SOLID_CHROM1-22_v.3.3.2_highconf_noincons"

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

### Submit a Spark job to execute DeepVariant in parallel

```

```


### Result

```

```

## Execution Time

Step                               | 2-Workers cluster | 4-Workers Cluster | 8-Workers Cluster | 16-Workers Cluster |
---------------------------------- | ----------------- | ----------------- | ----------------- | ------------------ |
`transform_data`                   |                   | 36m 08s           |                   |                    |
`select_bam`                       |                   | 18m 09s           |                   |                    |
`make_examples`                    |                   | 1h 57m 22s        |                   |                    |
`call_variants`                    |                   | 6h 23m 40s        |                   |                    |
`postprocess_variants` (no gVCF)   |                   | 4m 15s            |                   |                    |
`postprocess_variants` (with gVCF) | 55m 47s           |                   |                   |                    |
Total time                         | 5h 33m - 6h 07m   |                   |                   |                    |

## Delete Cluster

```
gcloud beta dataproc clusters delete my-deepvariant-on-spark
```
