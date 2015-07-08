#!/bin/bash -xe

# Delete some files on slave at most once a day.
# Stores a marker file with date of last deletion.

VENV=~/.venv


MARKER=$VENV/CREATED

if [[ -f $MARKER ]] ; then

    TODAY=$(date '+%Y%m%d')
    # Delete only once a day
    if [[ $(date -f $MARKER '+%Y%m%d') != TODAY ]] ; then
        rm -rf $VENV
    fi
fi

# Create marker file if it does not exist.

if [[ ! -d $VENV ]] ; then
    mkdir -p $VENV
fi

if [[ ! -f $MARKER ]] ; then
    date '+%Y%m%d' > $MARKER
fi
