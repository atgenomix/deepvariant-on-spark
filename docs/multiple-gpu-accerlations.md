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
gcloud beta dataproc clusters create deepvariant-on-spark \
  --subnet default --zone us-west1-b \
  --master-machine-type n1-highmem-8 --master-boot-disk-size 256 \
  --num-workers 5 --worker-machine-type n1-highmem-16 \
  --worker-boot-disk-size 384 \
  --worker-accelerator type=nvidia-tesla-p100,count=1 \
  --num-worker-local-ssds 1 --image-version 1.2.59-deb9  \
  --initialization-actions gs://seqslab-deepvariant/scripts/initialization-on-dataproc.sh  \
  --initialization-action-timeout 20m
```


