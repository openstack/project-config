#!/bin/bash -xe


GITHEAD=$(git rev-parse HEAD)

# Check out previous version
git checkout HEAD~1

cp gerrit/projects.yaml gerrit/projects-old.yaml

# Back to current version. Otherwise the
# check_gerrit_projects_changed.py invocation might be an old version.
git checkout $GITHEAD

python tools/check_gerrit_projects_changed.py gerrit/projects-old.yaml \
    gerrit/projects.yaml

rm gerrit/projects-old.yaml
