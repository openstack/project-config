#!/bin/bash

T=$(mktemp -d)
trap "rm -rf $T" EXIT

channels_file=${1:-gerritbot/channels.yaml}

# strip comments so that output can be compared meaningfully
(printf "# This file is sorted alphabetically by channel name.\n"; sed '/^[[:space:]]*#.*$/d;s/[[:space:]]*#.*$//' gerritbot/channels.yaml) > $T/comments-removed
./tools/normalize_channels_yaml.py >$T/regenned

diff -u $T/comments-removed $T/regenned
