# Trobuleshooting

## Check Error Message

You can directly check error messages from [Google DataProc Portal](https://console.cloud.google.com/dataproc/clusters)
to figure out which step was failed. Or DataProc keeps all of messages
in `/var/log/dataproc-initialization-script-0.log` of each instance. The
below messages are examples if successfully launching your DataProc
cluster:

```
user@my-dos-m:~$ tail -f /var/log/dataproc-initialization-script-0.log
Setting up python-dev (2.7.13-2) ...
Setting up libpython-all-dev:amd64 (2.7.13-2) ...
Setting up python-all-dev (2.7.13-2) ...
+ pip install jinja2
Requirement already satisfied: jinja2 in /usr/lib/python2.7/dist-packages
Requirement already satisfied: MarkupSafe in /usr/lib/python2.7/dist-packages (from jinja2)
+ systemctl restart hadoop-yarn-resourcemanager
+ echo '[info] setup_drivers.sh done'
[info] setup_drivers.sh done
[info] initialization_actions.sh done

user@my-dos-w-0:~$ tail -f /var/log/dataproc-initialization-script-0.log
Copying gs://deepvariant/models/DeepVariant/0.7.0/DeepVariant-inception_v3-0.7.0+data-wes_standard/model.ckpt.data-00000-of-00001...
Copying gs://deepvariant/models/DeepVariant/0.7.0/DeepVariant-inception_v3-0.7.0+data-wes_standard/model.ckpt.index...
Copying gs://deepvariant/models/DeepVariant/0.7.0/DeepVariant-inception_v3-0.7.0+data-wes_standard/model.ckpt.meta...
\ [3 files][362.2 MiB/362.2 MiB]
Operation completed over 3 objects/362.2 MiB.
+ lspci
+ grep -q NVIDIA
+ echo '[info] setup_drivers.sh done'
[info] setup_drivers.sh done
[info] initialization_actions.sh done
```

## Check Environment

DeepVariant will be installed into each worker node. You can login the
terminal of the first worker via Google Cloud Platform or the following
command:

```
gcloud compute ssh --ssh-flag="-A" my-dos-w-0 --zone="us-west1-b"
```

### Verify DeepVariant Package

DeepVariant will be installed in /usr/local/seqslab/deepvariant, so you can check
whether the following subfolders are existed in the folder or not.
```
user@my-dos-w-0:~$ ls -al /usr/local/seqslab/deepvariant/
drwxr-sr-x  2 root staff 4096 Jan  4 05:50 DeepVariant-inception_v3-0.7.0+data-wes_standard
drwxr-sr-x  2 root staff 4096 Jan  4 05:50 DeepVariant-inception_v3-0.7.0+data-wgs_standard
```

The models of DeepVariant comprises WGS and WES

```
user@my-dos-w-0:~$ ls -al /usr/local/seqslab/deepvariant/DeepVariant-inception_v3-0.7.0+data-wgs_standard
-rw-r--r--  1 root staff 348681272 Jan  4 05:50 model.ckpt.data-00000-of-00001
-rw-r--r--  1 root staff     18496 Jan  4 05:50 model.ckpt.index
-rw-r--r--  1 root staff  31106596 Jan  4 05:50 model.ckpt.meta
```

```
user@my-dos-w-0:~$ ls -al /usr/local/seqslab/deepvariant/DeepVariant-inception_v3-0.7.0+data-wes_standard
-rw-r--r--  1 root staff 348681272 Jan  4 05:50 model.ckpt.data-00000-of-00001
-rw-r--r--  1 root staff     18473 Jan  4 05:50 model.ckpt.index
-rw-r--r--  1 root staff  31118992 Jan  4 05:50 model.ckpt.meta
```

All executables are ready in `/usr/local/seqslab/deepvariant/bazel-bin/deepvariant/`

```
user@my-dos-w-0:~$ ls -al /usr/local/seqslab/deepvariant/bazel-bin/deepvariant/
-r-xr-xr-x 1 root staff 5874931 Jan  4 05:50 call_variants
-r-xr-xr-x 1 root staff 9807273 Jan  4 05:50 make_examples
-r-xr-xr-x 1 root staff 7839862 Jan  4 05:50 postprocess_variants
```

If the above files are existed, DeepVariant is installed successfully.

## How to stop the pipeline ?

If you would like to stop the pipeline for any reason, you have to do
two steps to stop all of jobs and release those allocated resources.

First, use `Ctrl+C` to stop the pipeline process from your shell screen,
so no more new jobs will be submitted. Secondly, we have to kill the
running jobs in YARN. Therefore, we have to collect the application ID
by using this command.

```
yarn application -list
```

When the application ID is acquired, you can use the following command
to kill it. If there are multiple running jobs, you have to kill them
one-by-one.

```
yarn application -kill <application ID>
```

## How to monitor the progress of the pipeline ?

<TBD>

