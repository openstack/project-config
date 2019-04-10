#!/bin/bash

T=$(mktemp -d)
trap "rm -rf $T" EXIT

channels_file=${1:-gerritbot/channels.yaml}

./tools/normalize_channels_yaml.py >$T/regenned

echo "Checking whether entries are sorted alphabetically"
diff -u $channels_file $T/regenned
