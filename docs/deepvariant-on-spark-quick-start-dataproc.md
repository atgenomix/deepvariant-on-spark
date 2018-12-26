# DeepVariant-on-Spark Quick Start on Google Cloud

This is an explanation of how to launch DeepVariant-on-Spark in Google
Cloud.

## Background

## Launch Cluster

```
gcloud beta dataproc clusters create deepvariant-on-spark \
    --subnet default --zone us-west1-b \
    --master-machine-type n1-highmem-8 --master-boot-disk-size 1024 \
    --num-workers 5 --worker-machine-type n1-highmem-16 \
    --worker-boot-disk-size 384 \
    --worker-accelerator type=nvidia-tesla-p100,count=1 \
    --num-worker-local-ssds 1 --image-version 1.3-deb9  \
    --initialization-actions gs://seqslab-deepvariant/scripts/initialization-on-dataproc.sh  \
    --initialization-action-timeout 20m
```


## Delete Cluster

```
gcloud beta dataproc clusters delete deepvariant-on-spark
```

