#!/bin/bash
#
# Script to cut stable/foo release branch of a project
#
# All Rights Reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

set -e

if [[ $# -lt 3 ]]; then
    echo "Usage: $0 series repo_name version"
    echo
    echo "Example: $0 kilo openstack/oslo.config 1.9.2"
    exit 2
fi

TOOLSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $TOOLSDIR/functions

SERIES=$1
REPO=$2
VERSION=$3
LPROJECT="$PROJECT"

PROJECT=$(basename $REPO)

NEW_BRANCH="stable/$SERIES"

setup_temp_space stable-branch-$PROJECT-$SERIES
clone_repo $REPO
cd $REPO
LANG=C git review -s

if $(git branch -r | grep $NEW_BRANCH > /dev/null); then
    echo "A $NEW_BRANCH branch already exists !"
    cd ../..
    rm -rf $MYTMPDIR
    exit 0
fi

echo "Creating $NEW_BRANCH from $VERSION"
git branch $NEW_BRANCH $VERSION
REALSHA=`git show-ref -s $NEW_BRANCH`
git push gerrit $NEW_BRANCH

update_gitreview "$NEW_BRANCH"
update_upper_constraints "$NEW_BRANCH"
if [[ -d releasenotes/source ]]; then
    # Also update the reno settings, in master
    echo "Updating reno"
    git checkout master
    $TOOLSDIR/add_release_note_page.sh $SERIES .
else
    echo "$REPO does not use reno, no update needed"
fi
