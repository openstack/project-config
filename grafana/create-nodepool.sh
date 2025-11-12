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
create Rackspace-Flex 'raxflex-*' nodepool-raxflex.yaml
create OVH 'ovh-*' nodepool-ovh.yaml
create Vexxhost 'vexxhost-*' nodepool-vexxhost.yaml
create OSUOSL 'osuosl-*' nodepool-osuosl.yaml
create OpenMetal 'openmetal-*' nodepool-openmetal.yaml

function create_zuul {
    local template="$1"
    local provider="$2"
    local stat_list="$3"
    local output_file="$4"

    sed -e "s/%PROVIDER%/${provider}/g; " \
        -e "s/%STAT_LIST%/${stat_list}/" \
        -e "s/%TEMPLATE%/${template}/" \
        ${template} > ${output_file}
}

# Templates vary depending on which resource limits are included:
# zuul-launcher-ram-ir.template : instances, ram
# zuul-launcher-ram-icr.template : instances, cores, ram

create_zuul zuul-launcher-ir.template Rackspace 'rax' zuul-launcher-rax.json
create_zuul zuul-launcher-icr.template Rackspace-Flex 'raxflex' zuul-launcher-raxflex.json
create_zuul zuul-launcher-icr.template OVH 'ovh' zuul-launcher-ovh.json
create_zuul zuul-launcher-icr.template Vexxhost 'vexxhost' zuul-launcher-vexxhost.json
create_zuul zuul-launcher-icr.template OSUOSL 'osuosl' zuul-launcher-osuosl.json
create_zuul zuul-launcher-icr.template OpenMetal 'openmetal' zuul-launcher-openmetal.json
