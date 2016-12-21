#!/bin/bash -xe

# Working variables
WHEELHOUSE_DIR=$1
PROJECT=openstack/requirements
WORKING_DIR=`pwd`/$PROJECT
PYTHON_VERSION=$2

# Extract and iterate over all the branch names.
BRANCHES=`git --git-dir=$WORKING_DIR/.git branch -r | grep '^  origin/[^H]'`
for BRANCH in $BRANCHES; do
    git --git-dir=$WORKING_DIR/.git show $BRANCH:upper-constraints.txt \
        2>/dev/null > /tmp/upper-constraints.txt  || true
    rm -rf build_env
    virtualenv -p $PYTHON_VERSION build_env
    for pkg in $(cat /tmp/upper-constraints.txt); do
        build_env/bin/pip --log $WORKSPACE/pip.log -w $WHEELHOUSE_DIR "${pkg}" || \
            echo "*** WHEEL BUILD FAILURE: ${pkg}"
    done
done
