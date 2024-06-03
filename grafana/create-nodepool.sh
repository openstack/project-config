#!/bin/bash

#
# Creates graphs for nodepool regions from a given provider
#
# Note we are somewhat particular about keeping these separate to
# avoid the idea that we are providing some sort of cross-provider
# benchmark.
#

function create {
    local provider="$1"
    local stat_list="$2"
    local output_file="$3"

    sed -e "s/%PROVIDER%/${provider}/; " \
        -e "s/%STAT_LIST%/${stat_list}/" \
        -e "s/%OUTPUT_FILE%/${output_file}/" \
        nodepool.template > ${output_file}
}

create Rackspace 'rax-*' nodepool-rax.yaml
create Linaro 'linaro-*' nodepool-linaro.yaml
create OVH 'ovh-*' nodepool-ovh.yaml
create Vexxhost 'vexxhost-*' nodepool-vexxhost.yaml
create OSUOSL 'osuosl-*' nodepool-osuosl.yaml
