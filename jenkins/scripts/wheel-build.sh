#!/bin/bash -xe

# Working variables
WHEELHOUSE_DIR=$1
PROJECT=openstack/requirements
WORKING_DIR=`pwd`/$PROJECT

# Extract and iterate over all the branch names.
BRANCHES=`git --git-dir=$WORKING_DIR/.git branch -r | grep '^  origin/[^H]'`
for BRANCH in $BRANCHES; do
    git --git-dir=$WORKING_DIR/.git show $BRANCH:upper-constraints.txt \
        2>/dev/null > /tmp/upper-constraints.txt  || true
    python -m pip --verbose wheel -r /tmp/upper-constraints.txt -w $WHEELHOUSE_DIR || true
    python3 -m pip --verbose wheel -r /tmp/upper-constraints.txt -w $WHEELHOUSE_DIR || true
done
