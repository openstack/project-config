#!/bin/bash
#
# Script to create branches for a project
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
set -x

if [[ $# -lt 3 ]]; then
    echo "Usage: $0 repo_name branch_name git_reference"
    echo
    echo "Example: $0 openstack/oslo.config stable/kilo 1.9.2"
    exit 2
fi

function cleanup_and_exit {
    cd ../..
    rm -rf $MYTMPDIR
    exit 0
}

TOOLSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $TOOLSDIR/functions

REPO=$1
NEW_BRANCH=$2
START_POINT=$3
MASTER_BRANCH_NAME=${4:-}
LPROJECT="$PROJECT"

PROJECT=$(basename $REPO)

branch_as_path_entry=$(echo $NEW_BRANCH | sed -s 's|/|-|g')

setup_temp_space branch-$PROJECT-$branch_as_path_entry
clone_repo $REPO
cd $REPO

# Skip branch creation in case bugfix-<version>-eol tag exists
if $(git tag | grep ${NEW_BRANCH/\//-}-eol > /dev/null); then
    echo "A ${NEW_BRANCH/\//-}-eol tag already exists !"
    cleanup_and_exit
fi

# Skip stable/<series> branch creation in case <series>-eol tag exists
if $(git tag | grep ${NEW_BRANCH#stable/}-eol >/dev/null); then
    echo "A ${NEW_BRANCH#stable/}-eol tag already exists !"
    cleanup_and_exit
fi

# Skip unmaintained/<series> branch creation in case <series>-eol tag exists
if $(git tag | grep ${NEW_BRANCH#unmaintained/}-eol >/dev/null); then
    echo "A ${NEW_BRANCH#unmaintained/}-eol tag already exists !"
    cleanup_and_exit
fi

# Skip stable/<series> branch creation in case <series>-eom tag exists
if $(git tag | grep ${NEW_BRANCH#stable/}-eom >/dev/null); then
    echo "A ${NEW_BRANCH#stable/}-eom tag already exists !"
    cleanup_and_exit
fi

if $(git branch -r | grep $NEW_BRANCH > /dev/null); then
    echo "A $NEW_BRANCH branch already exists !"
    cleanup_and_exit
fi

# NOTE(dhellmann): We wait to set up git-review until after we have
# checked for the branch and then check out the tagged point to create
# the branch in case the master branch has been retired since then and
# there is no longer a .gitreview file there.
LANG=C git checkout $START_POINT
LANG=C git review -s

echo "Creating $NEW_BRANCH from $START_POINT"
git branch $NEW_BRANCH $START_POINT
REALSHA=`git show-ref -s $NEW_BRANCH`
git push gerrit $NEW_BRANCH

update_gitreview "$NEW_BRANCH"

# Do not update upper constraints on driverfixes or intermediate branches
if [[ ! $NEW_BRANCH =~ driverfixes/|bugfix/ ]]; then
    update_upper_constraints "$NEW_BRANCH"
fi

if [[ $NEW_BRANCH =~ stable/ ]]; then
    series=$(echo $NEW_BRANCH | cut -f2 -d/)
    if [[ -d releasenotes/source ]]; then
        # Also update the reno settings, in master, to add the new
        # series page and bump the SemVer value for feature work.
        echo "Updating reno and semver"
        git checkout master
        $TOOLSDIR/add_release_note_page.sh $series .
    else
        echo "$REPO does not use reno, no update needed"
    fi
fi

if [[ $NEW_BRANCH =~ unmaintained/ ]]; then
    series=$(echo $NEW_BRANCH | cut -f2 -d/)
    if [[ -d releasenotes/source ]]; then
        echo "Updating reno to use unmaintained/$series"
        git checkout master
        $TOOLSDIR/change_reno_branch_to_unmaintained.sh $series .
    else
        echo "$REPO does not use reno, no update needed"
    fi
fi
