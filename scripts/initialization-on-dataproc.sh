#!/usr/bin/env bash
echo "[info] initialization_actions.sh start"
wget https://raw.githubusercontent.com/atgenomix/deepvariant-on-spark/master/scripts/initialization_actions.sh
bash ./initialization_actions.sh
echo "[info] initialization_actions.sh done"

