#!/bin/bash -xe

for n in nodepool/n*.yaml ; do
    nodepool -c $n config-validate
done
