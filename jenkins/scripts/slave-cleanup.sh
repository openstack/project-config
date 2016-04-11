#!/bin/bash -xe

# Delete some files on slave at most once a day.
# Stores a marker file with date of last deletion.

MARKER=.marker_CREATED

if [[ -f $MARKER ]] ; then

    TODAY=$(date '+%Y%m%d')
    # Delete only once a day
    if [[ $(date -f $MARKER '+%Y%m%d') != $TODAY ]] ; then
        # Let's see how much we delete.
        # Let du report sizes each directory.
        du -h --max-depth=1 .
        git clean -f -x -d
        du -h --max-depth=1 .
    fi
fi

# Create marker file if it does not exist.

if [[ ! -f $MARKER ]] ; then
    date '+%Y%m%d' > $MARKER
fi
