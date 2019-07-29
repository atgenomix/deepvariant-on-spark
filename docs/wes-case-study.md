# DeepVariant-on-Spark WES case study

In this case study we describe applying DeepVariant-on-Spark to a real
WES sample.

## Background

We use the same WES data from DeepVariant for demonstration.

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

In this example, there are 2 worker nodes launched and each node has 16
vcores with 104 GB memory.

```
gcloud beta dataproc clusters create my-dos \
  --subnet default --zone us-west1-b \
  --master-machine-type n1-highmem-8 --master-boot-disk-size 256 \
  --num-workers 2 --worker-machine-type n1-highmem-16 \
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

## Run a WES sample from Google Storage Bucket

One simple command to run the whole pipeline.

```
bash ./deepvariant-on-spark/scripts/WES/wes.sh gs://deepvariant/exome-case-study-testdata/151002_7001448_0359_AC7F6GANXX_Sample_HG002-EEogPU_v02-KIT-Av5_AGATGTAC_L008.posiSrt.markDup.bam 19 GRCH agilent_sureselect_human_all_exon_v5_b37_targets.bed output
```

### Usage

```
Usage:
	 ./deepvariant-on-spark/scripts/WES/wes.sh <Input BAM> <Reference Version> <Contig Style> <exon-kit> <Output Folder> [GVCF]
Parameters:
	 <Input BAM>: the input bam file from Google Strorage or HDFS
	 <Reference Version>: [ 19 | 38 ]
	 <Contig Style>: [ HG | GRCH ]
         <Exon-kit>: 
               hg19 [ Broad_human_exome_b37_interval_list | SeqCap_EZ_Human_Exome_v3+UTR | 
                      SureSelect_Clinical_Research_Exome_V2 | SureSelect_Human_All_Exon_V5 | 
                      SureSelect_Human_All_Exon_V6+COSMIC_r2 | SureSelect_Human_All_Exon_V6+UTR_r2 | 
                      SureSelect_Human_All_Exon_V6_r2 | SureSelect_Human_All_Exon_V7 | 
                      truseq-exome-targeted-regions-manifest-v1-2 ]
                      
               hg38 [ SureSelect_Clinical_Research_Exome_V2 | SureSelect_Human_All_Exon_V6+COSMIC_r2 | 
                      SureSelect_Human_All_Exon_V6+UTR_r2 | SureSelect_Human_All_Exon_V6_r2 | 
                      SureSelect_Human_All_Exon_V7 | truseq-exome-targeted-regions-manifest-v1-2_hg38 ]
	 <Output Folder>: the output folder on HDFS
	 GVCF: the gvcf will be generated if enabled
Examples:
	 ./deepvariant-on-spark/scripts/WES/wes.sh gs://deepvariant/exome-case-study-testdata/151002_7001448_0359_AC7F6GANXX_Sample_HG002-EEogPU_v02-KIT-Av5_AGATGTAC_L008.posiSrt.markDup.bam 19 GRCH agilent_sureselect_human_all_exon_v5_b37_targets.bed output
	 ./deepvariant-on-spark/scripts/WES/wes.sh gs://deepvariant/exome-case-study-testdata/151002_7001448_0359_AC7F6GANXX_Sample_HG002-EEogPU_v02-KIT-Av5_AGATGTAC_L008.posiSrt.markDup.bam 19 GRCH agilent_sureselect_human_all_exon_v5_b37_targets.bed output GVCF
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
1    | `transform_data`       |     10m 53s    |
2    | `select_bam`           |     04m 28s    |
3    | `make_examples`        |     40m 46s    |
4    | `call_variants`        |     03m 13s    |
5    | `postprocess_variants` |     01m 00s    |
6    | `merge_vcf`            |     00m 05s    |
Sum  | Total time             |  1h 25s        |

## Scalability

DeepVariant-on-Spark leverage Apache Spark to support distributed
computation, so it can be easily scaled out. Here, we try to run the
whole pipeline in clusters with different numbers of nodes (2^N; N=1~3)
and observe the performance improvement.

Step                   | 2-Workers cluster | 4-Workers Cluster | 8-Workers Cluster |
---------------------- | ----------------- | ----------------- | ----------------- |
`transform_data`       |     10m 53s       |            |            |
`select_bam`           |     04m 28s       |            |            |
`make_examples`        |     40m 46s       |         |         |
`call_variants`        |     03m 13s       |         |            |
`postprocess_variants` |     01m 00s       |          |             |
`merge_vcf`            |     00m 05s       |
Total time             |  1h 25s           |             |             |
Speed-up               | 1.00X             |              |              |

*change the number of workers by `--num-workers N` in the command for
 cluster launch.

*NOTE*: The default number of data sharding for WES in
DeepVariant-on-Spark is `by-chromosome`, so we won't gain significant improvement
when adding workers from 4 to 8 (from 64 to 128 vcores). If you prefer
to add more resources for fast turnaround time, please refer to [the
customerization page](customization.md) for more details.
