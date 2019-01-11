# Multiple GPU Acceleration

This is an performance report to show the relation between number of GPUs
and execution time.

## Background

Currently DeepVariant(v0.7.x) support single GPU, so we can't get any
benefit on multiple GPU machines, like nVidia DGX-1. Therefore,
DeepVariant-on-Spark leverage Apache Spark to launch multiple DeepVariant
processes in parallel, so all of GPU resource can be fully utilized.

## Launch Cluster

```
gcloud beta dataproc clusters create my-dos \
  --subnet default --zone us-west1-b \
  --master-machine-type n1-highmem-8 --master-boot-disk-size 256 \
  --num-workers 4 --worker-machine-type n1-highmem-16 \
  --worker-boot-disk-size 384 \
  --worker-accelerator type=nvidia-tesla-p100,count=1 \
  --num-worker-local-ssds 1 --image-version 1.2.59-deb9  \
  --initialization-actions gs://seqslab-deepvariant/scripts/initialization-on-dataproc.sh  \
  --initialization-action-timeout 20m
```


## Command Line

Using [the same command](blob/master/docs/wgs-case-study.md#run-a-wgs-sample-from-google-storage-bucket)
 to demonstrate the performance improvement by adding more GPUs.

Since GPU acceleration is only leveraged by `call_variants` among the
whole pipeline, you can use the following command to execute this step
directly.

```
bash ./deepvariant-on-spark/script/call_variants.sh /output/examples /bed/19/contiguous_unmasked_regions_156_parts 19 GRCH /output/variants
```

### Usage

More details is described as follows:

```
Usage:
	 ./deepvariant-on-spark/scripts/call_variants.sh <Example folder> <BED folder> <Reference Version> <Contig Style> <Output Folder>
Parameters:
	 <Example folder>: the output folder of make_examples
	 <BED folder>: the bed file for Adaptive Data Parallelization (ADP)
	 <Reference Version>: [ 19 | 38 ]
	 <Contig Style>: [ HG | GRCH ]
	 <Output Folder>: the output folder on HDFS
Examples:
	 ./deepvariant-on-spark/scripts/call_variants.sh output_HG002/examples /bed/19/contiguous_unmasked_regions_156_parts 19 GRCH output_HG002/variants
```

## Performance Comparision

The following table shows the execution time of the step
in different numbers of GPUs.

Step            | Pure CPU cluster | 1-GPU Cluster | 2-GPU Cluster | 4-GPU Cluster |
--------------- | ---------------- | ------------- | ------------- | ------------- |
`call_variants` | 6h 23m 40s       |               |               |               |

*Machine Spec. : 16-vCores with 104 GB memory (n1-highmem-16) * 4
