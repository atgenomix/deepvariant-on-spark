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
  --min-cpu-platform "Intel Skylake" \
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

One simple command to run the whole pipeline.

```
bash ./deepvariant-on-spark/scripts/run.sh gs://seqslab-deepvariant/case-study/input/data/HG002_NIST_150bp_50x.bam 19 GRCH output
```

##### Note
SeqPiper CAN NOT process the BAM file (gs://deepvariant/case-study/input/data/HG002_NIST_150bp_50x.bam)
 provided from DeepVariant team since the file is generated from old HTSLib
 and caused the parsing error by Apache ADAM. Therefore, we use Samtools
 to regenerate the new BAM by the following command and put into our
 Google Storage Bucket (gs://seqslab-deepvariant/case-study/input/data/HG002_NIST_150bp_50x.bam).

```
samtools view -h old.bam | samtools viewe -Sb - > new.bam
```

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
	 ./deepvariant-on-spark/scripts/run.sh gs://seqslab-deepvariant/case-study/input/data/HG002_NIST_150bp_50x.bam 19 GRCH /output_HG002
	 ./deepvariant-on-spark/scripts/run.sh gs://seqslab-deepvariant/case-study/input/data/HG002_NIST_150bp_50x.bam 19 GRCH /output_HG002 GVCF
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
42.6 G   /output/examples
246.0 M  /output/variants
101.1 M  /output/vcf
```

### Performance Evaluation

The execution time of each step is listed as follows:

Step | Module                 | Execution Time |
-----| ---------------------- | -------------- |
1    | `transform_data`       |     37m 35s    |
2    | `select_bam`           |     17m 21s    |
3    | `make_examples`        |  1h 41m 46s    |
4    | `call_variants`        |  5h 08m 04s    |
5    | `postprocess_variants` |      4m 17s    |
Sum  | Total time             |  7h 49m        |

## Scalability

DeepVariant-on-Spark leverage Apache Spark to support distributed
computation, so it can be easily scaled out. Here, we try to run the
whole pipeline in clusters with different numbers of nodes (2^N; N=1~4)
and observe the performance improvement.

Step                   | 2-Workers cluster | 4-Workers Cluster | 8-Workers Cluster | 16-Workers Cluster |
---------------------- | ----------------- | ----------------- | ----------------- | ------------------ |
`transform_data`       |  1h 09m 25s       |    43m 02s        |    23m 12s        |    17m 22s         |
`select_bam`           |     35m 13s       |    20m 23s        |    11m 53s        |    10m 54s         |
`make_examples`        |  3h 44m 13s       | 1h 51m 09s        | 1h 04m 05s        |    47m 47s         |
`call_variants`        | 12h 00m 20s       | 6h 14m 09s        | 3h 37m 06s        | 2h 59m 41s         |
`postprocess_variants` |      7m 36s       |     4m 16s        |     2m 49s        |     2m 05s         |
Total time             | 17h 37m           | 9h 13m            | 5h 19m            | 4h 18m             |
Speed-up               | 1.00X             | 1.91X             | 3.31X             | 4.10X              |

*change the number of workers by `--num-workers N` in the command for
 cluster launch.

*NOTE*: The default number of data sharding for WGS in
DeepVariant-on-Spark is `155`, so we won't gain significant improvement
when adding workers from 8 to 16 (from 128 to 256 vcores). If you prefer
to add more resources for fast turnaround time, please refer to [the
customerization page](customization.md) for more details.
