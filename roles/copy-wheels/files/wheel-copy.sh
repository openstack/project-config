#!/bin/bash -xe

# Working variables
WHEELHOUSE_DIR=$1
MIRROR_ROOT=$2

# Build our mirror folder structure.
for f in $WHEELHOUSE_DIR/*; do
    BASENAME=$(basename $f)
    IFS='-' read -a parts <<< $BASENAME

    # Normalize based on PEP503
    PACKAGENAME=`echo "${parts[0]}" | perl -pe 's/[-_.]+/-/g' | \
        tr '[:upper:]' '[:lower:]'`

    DEST_DIR="${PACKAGENAME:0:1}/$PACKAGENAME"

    # Create the mirror directories in AFS /s/split style. This
    # depends on the existence of a mod_rewrite script which unmunges
    # the path, and is required because AFS has a practical folder size
    # limit.
    if [ ! -f $MIRROR_ROOT/$DEST_DIR/$BASENAME ]; then
        mkdir -p $MIRROR_ROOT/$DEST_DIR
        cp $f $MIRROR_ROOT/$DEST_DIR/$BASENAME
    fi
done
