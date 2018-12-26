#!/usr/bin/env bash
echo "[info] initialization_actions.sh start"
wget https://raw.githubusercontent.com/atgenomix/deepvariant-on-spark/master/scripts/initialization-on-dataproc.sh
bash ./initialization-on-dataproc.sh
echo "[info] initialization_actions.sh done"
