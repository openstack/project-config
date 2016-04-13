#!/bin/bash -xe

# Cleanup workspace afterwards so that no extra files are in it.
# This is also done at beginning of each job but let's do it
# afterwards to save space on the workspace between invocations.

# Let's see how much we delete.
# Let du report sizes each directory.
du -h --max-depth=1 .
git clean -f -x -d
du -h --max-depth=1 .
