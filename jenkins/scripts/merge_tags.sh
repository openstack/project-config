#!/bin/bash -xe

# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

source /usr/local/jenkins/slave_scripts/common.sh

TAG=$1

# Only merge release tag if it's on a stable branch
if ! $(git branch -r --contains "$TAG" | grep "stable/" >/dev/null); then
    echo "Tag $TAG was not pushed to a stable branch, ignoring."
    exit 0
fi

# Make sure the tag does not correspond to a patch release
if ! echo $TAG|grep '^[0-9]\+\.[0-9]\+\(\.0\|\)$'; then
    echo "Triggered on patch release $TAG tag, ignoring."
    exit 0
fi

setup_git

git review -s
git remote update
git checkout master
git reset --hard origin/master
MASTER_MINOR=`git describe|cut -d. -f-2`
TAG_MINOR=`echo $TAG|cut -d. -f-2`

# If the tag is for an earlier version than master's, skip
if [ "$(echo $(echo -e "$MASTER_MINOR\n$TAG_MINOR"|sort -V))" \
    \!= "$MASTER_MINOR $TAG_MINOR" ]; then
    echo "Skipping $TAG which sorts before master's $MASTER_MINOR version."
    exit 0
fi

git merge --no-edit -s ours $TAG
# Get a Change-Id
GIT_EDITOR=true git commit --amend
git review -R -y -t merge/release-tag
