# DeepVariant-on-Spark WGS case study

In this case study we describe applying DeepVariant-on-Spark to a real
WGS sample.

## Background

We use the same WGS data from DeepVariant for demonstration.

NOTE: This case study demonstrates an example of how to run
DeepVariant-on-Spark end-to-end pipeline on Google DataProc. This might
not be the fastest or cheapest configuration for your needs.

## Launch CPU Cluster

Before launching a Dataproc with GPU hardware, you should check whether
you have enough quota for your use case. As your use of Google Cloud
Platform expands over time, your quotas may increase accordingly. If you
expect a notable upcoming increase in usage, you can proactively
[request quota](https://cloud.google.com/compute/quotas#request_quotas)
adjustments from the Quotas page in the GCP Console.

In this example, there are 5 worker nodes launched and each node has 16
vcores with 104 GB memory.

```
gcloud beta dataproc clusters create my-dos \
  --subnet default --zone us-west1-b \
  --master-machine-type n1-highmem-8 --master-boot-disk-size 256 \
  --num-workers 5 --worker-machine-type n1-highmem-16 \
  --worker-min-cpu-platform "Intel Skylake" \
  --worker-boot-disk-size 384 \
  --num-worker-local-ssds 1 --image-version 1.2.59-deb9  \
  --initialization-actions gs://seqslab-deepvariant/scripts/initialization-on-dataproc.sh  \
  --initialization-action-timeout 20m \
  --properties=^--^capacity-scheduler:yarn.scheduler.capacity.resource-calculator=org.apache.hadoop.yarn.util.resource.DominantResourceCalculator--yarn:yarn.scheduler.maximum-allocation-mb=103424--yarn:yarn.nodemanager.resource.memory-mb=103424
```

After the cluster has been launched, please follow [the quick-start guide
for DataProc](deepvariant-on-spark-quick-start-dataproc.md#initialize-deepvariant-on-spark-dos)
to install DeeopVariant-on-Spark.

## Run a WGS sample from Google Storage Bucket


### Usage

```
Usage:
	 ./deepvariant-on-spark/scripts/run.sh <Input BAM> <Reference Version> <Contig Style> <Output Folder> [GVCF]
Parameters:
	 <Input BAM>: the input bam file from Google Strorage or HDFS
	 <Reference Version>: [ 19 | 38 ]
	 <Contig Style>: [ HG | GRCH ]
	 <Output Folder>: the output folder on HDFS
	 GVCF: the gvcf will be generated if enabled
Examples:
	 ./deepvariant-on-spark/scripts/run.sh gs://deepvariant/case-study-testdata/HG002_NIST_150bp_50x.bam 19 GRCH /output_HG002
	 ./deepvariant-on-spark/scripts/run.sh gs://deepvariant/case-study-testdata/HG002_NIST_150bp_50x.bam 19 GRCH /output_HG002 GVCF
```
*Note*:
SeqPiper CAN NOT process the BAM file (gs://deepvariant/case-study/input/data/HG002_NIST_150bp_50x.bam)
provided from DeepVariant team since the file is generated from old HTSLib
and caused the parsing error by Apache ADAM. Therefore, we use Samtools
to regenerate the new BAM by the following command and put into our
Google Storage Bucket (gs://seqslab-deepvariant/case-study/input/data/HG002_NIST_150bp_50x.bam).

```
samtools view -h old.bam | samtools viewe -Sb - > new.bam
```

*Note*: If you would like to stop the pipeline for any reason, please
refer to [How to stop the pipeline?](trobuleshooting.md#how-to-monitor-the-progress-of-the-pipeline-)
for more details.

### Result

Then, all of outputs and their size are listed as follows:

```
user@my-dos-m:~$ hadoop fs -du -h /output
101.1 G  /output/alignment.bam
155.6 G  /output/alignment.parquet
42.7 G   /output/examples
246.1 M  /output/variants
101.1 M  /output/vcf
```

### Performance Evaluation

The execution time of each step is listed as follows:

Step | Module                 | Execution Time |
-----| ---------------------- | -------------- |
1    | `transform_data`       |     31m 17s    |
2    | `select_bam`           |     14m 56s    |
3    | `make_examples`        |  1h 22m 09s    |
4    | `call_variants`        |  1h 03m 26s    |
5    | `postprocess_variants` |      3m 31s    |
Sum  | Total time             |  3h 15m        |

## Scalability

DeepVariant-on-Spark leverage Apache Spark to support distributed
computation, so it can be easily scaled out. Here, we try to run the
whole pipeline in clusters with different numbers of nodes (2^N; N=1~3)
and observe the performance improvement.

Step                   | 2-Workers cluster | 4-Workers Cluster | 8-Workers Cluster |
---------------------- | ----------------- | ----------------- | ----------------- |
`transform_data`       |  1h 09m 07s       |    39m 44s        |    21m 14s        |
`select_bam`           |     34m 30s       |    18m 04s        |    11m 33s        |
`make_examples`        |  3h 31m 29s       | 1h 47m 39s        | 1h 00m 16s        |
`call_variants`        |  2h 35m 20s       | 1h 20m 49s        |    51m 00s        |
`postprocess_variants` |      7m 07s       |     4m 06s        |     2m 42s        |
Total time             |  7h 58m           | 4h 10m            | 2h 27m            |
Speed-up               | 1.00X             | 1.91X             | 3.25X             |

*change the number of workers by `--num-workers N` in the command for
 cluster launch.

*NOTE*: The default number of data sharding for WGS in
DeepVariant-on-Spark is `155`, so we won't gain significant improvement
when adding workers from 4 to 8 (from 64 to 128 vcores). If you prefer
to add more resources for fast turnaround time, please refer to [the
customerization page](customization.md) for more details.
