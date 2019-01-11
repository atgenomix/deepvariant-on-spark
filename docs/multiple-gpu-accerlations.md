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
gcloud beta dataproc clusters create my-dos1 \
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

### Quick Start

If you don't want to run the whole pipeline, you have to download the
output of `make_examples` for HG002_NIST_150bp_50x.bam. The data is
available on gs://seqslab-deepvariant/case-study/output/examples/*.gz
and all of necessary data will be settled by the commands.

```
mkdir examples
gsutil -m cp -r gs://seqslab-deepvariant/case-study/output/examples/* examples/
hadoop fs -mkdir -p /output/examples
hadoop fs -put examples/*.gz /output/examples/
```

Since GPU acceleration is only leveraged by `call_variants` among the
whole pipeline, you can use the following command to execute this step
directly.

```
bash ./deepvariant-on-spark/scripts/call_variants.sh /output/examples /bed/19/contiguous_unmasked_regions_156_parts 19 GRCH /output/variants
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

The following table shows the execution time of the step `call_variants`
in different numbers of GPUs.

Hardware Spec.  | Pure CPU cluster | 1-GPU Cluster | 2-GPU Cluster | 4-GPU Cluster |
--------------- | ---------------- | ------------- | ------------- | ------------- |
Execution Time  | 6h 23m 40s       |    16m 46s    |    9m 34s     |    7m 19s     |

* The number of GPU cards is adjustable by changing `N` of
`--worker-accelerator type=nvidia-tesla-p100,count=N` when cluster
launch.
* Machine Spec. : 16-vCores with 104 GB memory (n1-highmem-16) * 4

### Multiple-GPU Acceleration

If the cluster with 4-GPUs node is launched, you can find the full
utilization of GPU resources by using `nvidia-smi` as follows:

```
Fri Jan 11 22:35:59 2019
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 390.87                 Driver Version: 390.87                    |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  Tesla P100-PCIE...  Off  | 00000000:00:05.0 Off |                    0 |
| N/A   62C    P0   171W / 250W |  16112MiB / 16280MiB |    100%      Default |
+-------------------------------+----------------------+----------------------+
|   1  Tesla P100-PCIE...  Off  | 00000000:00:06.0 Off |                    0 |
| N/A   65C    P0   166W / 250W |  15624MiB / 16280MiB |    100%      Default |
+-------------------------------+----------------------+----------------------+
|   2  Tesla P100-PCIE...  Off  | 00000000:00:07.0 Off |                    0 |
| N/A   63C    P0   163W / 250W |  15624MiB / 16280MiB |    100%      Default |
+-------------------------------+----------------------+----------------------+
|   3  Tesla P100-PCIE...  Off  | 00000000:00:08.0 Off |                    0 |
| N/A   60C    P0   157W / 250W |  16070MiB / 16280MiB |    100%      Default |
+-------------------------------+----------------------+----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                       GPU Memory |
|  GPU       PID   Type   Process name                             Usage      |
|=============================================================================|
|    0     19863      C   /usr/bin/python                             4227MiB |
|    0     19868      C   /usr/bin/python                             4227MiB |
|    0     19880      C   /usr/bin/python                             4225MiB |
|    0     22558      C   /usr/bin/python                             3421MiB |
|    1     19876      C   /usr/bin/python                             4225MiB |
|    1     20093      C   /usr/bin/python                             4225MiB |
|    1     20094      C   /usr/bin/python                             4225MiB |
|    1     21556      C   /usr/bin/python                             2937MiB |
|    2     19864      C   /usr/bin/python                             4225MiB |
|    2     19874      C   /usr/bin/python                             4225MiB |
|    2     20095      C   /usr/bin/python                             4225MiB |
|    2     21555      C   /usr/bin/python                             2937MiB |
|    3     19879      C   /usr/bin/python                             4227MiB |
|    3     21986      C   /usr/bin/python                             3513MiB |
|    3     22495      C   /usr/bin/python                             4225MiB |
|    3     22686      C   /usr/bin/python                             4093MiB |
+-----------------------------------------------------------------------------+
```
