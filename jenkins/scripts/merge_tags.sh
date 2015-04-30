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

TAG=$1

# Avoid acting on any tag which is not strictly an all-numeric/stops string
# since the logic below relies on a simple numeric sort. Ordering of
# non-numeric strings are locale-specific, and situations like PEP-440 violate
# assumptions about non-numeric versions being alpha-sorted anyway. This check
# is redundant since we should never allow a tag containing non-numeric version
# components through the filter for the release pipeline in Zuul, but is here
# as a safeguard to validate that expectation since "Git tags are forever."
if ! echo $TAG|grep '^[0-9\.]*$'; then
    echo "ERROR: Triggered on non-release $TAG tag."
    exit 1
fi

git config user.name "OpenStack Proposal Bot"
git config user.email "openstack-infra@lists.openstack.org"
git config gitreview.username "proposal-bot"

git review -s
git remote update
git checkout master
git reset --hard origin/master
MASTER_MINOR=`git describe|cut -d. -f-2`
TAG_MINOR=`echo $TAG|cut -d. -f-2`

# If the tag is for a patch version where its minor matches master's, skip
if [ "$MASTER_MINOR" = "$TAG_MINOR" ]; then
    echo "Skipping $TAG which shares master's $MASTER_MINOR version."
    exit 0
fi

# If the tag is for an earlier version than master's, skip
if [ "$(echo $(echo -e "$MASTER_MINOR\n$TAG_MINOR"|sort -V))" \
    = "$TAG_MINOR $MASTER_MINOR" ]; then
    echo "Skipping $TAG which sorts before master's $MASTER_MINOR version."
    exit 0
fi

git merge --no-edit -s ours $TAG
# Get a Change-Id
GIT_EDITOR=true git commit --amend
git review -R -y -t merge/release-tag
