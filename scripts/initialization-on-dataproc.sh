#!/usr/bin/env bash
echo "[info] initialization_actions.sh start"
gsutil cp gs://dataproc-3b095611-db2b-4155-8021-a922552cb1aa-us/initialization_actions.sh .
bash ./initialization_actions.sh
echo "[info] initialization_actions.sh done"

