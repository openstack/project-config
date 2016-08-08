#!/bin/bash
#
# Script to release a project in one shot, including the git tag and
# launchpad updates.
#
# Copyright 2015 Thierry Carrez <thierry@openstack.org>
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

set -ex

TOOLSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $TOOLSDIR/functions

function usage {
    echo "Usage: release.sh [-a] repository series version diff_start SHA announce include_pypi first-full-release extra-metadata"
    echo
    echo "Example: release.sh openstack/oslo.rootwrap mitaka 3.0.3 '' gerrit/master openstack-dev@lists.openstack.org yes no 'meta:release:Workflow+1: Doug Hellmann <doug@doughellmann.com>'"
}

if [ $# -lt 5 ]; then
    usage
    exit 2
fi

REPO=$1
SERIES=$2
VERSION=$3
DIFF_START=$4
SHA=$5
ANNOUNCE=$6
INCLUDE_PYPI=${7:-no}
FIRST_FULL=${8:-no}
EXTRA_METADATA="$9"

SHORTNAME=`basename $REPO`

pre_release_pat='\.[[:digit:]]+[ab][[:digit:]]+'
rc_release_pat='\.[[:digit:]]+rc[[:digit:]]+'
if [[ $VERSION =~ $pre_release_pat ]]; then
    RELEASETYPE="development milestone"
elif [[ $VERSION =~ $rc_release_pat ]]; then
    RELEASETYPE="release candidate"
else
    RELEASETYPE="release"
fi

setup_temp_space release-tag-$SHORTNAME
clone_repo $REPO
REPODIR="$(cd $REPO && pwd)"
cd $REPODIR
TARGETSHA=`git log -1 $SHA --format='%H'`

# Determine the most recent tag before we add the new one.
PREVIOUS=$(get_last_tag $TARGETSHA)

echo "Tagging $TARGETSHA as $VERSION"
if git show-ref "$VERSION"; then
    echo "$REPO already has a version $VERSION tag"
    # Reset the notion of "previous" to the version associated with
    # the parent of the commit being tagged, since the tag we're
    # applying already exists.
    PREVIOUS=$(get_last_tag ${TARGETSHA}^1)
else
    # WARNING(dhellmann): announce.sh expects to be able to parse this
    # commit message, so if you change the format you may have to
    # update announce.sh as well.
    TAGMSG="$SHORTNAME $VERSION $RELEASETYPE

meta:version: $VERSION
meta:diff-start: $DIFF_START
meta:series: $SERIES
meta:release-type: $RELEASETYPE
meta:announce: $ANNOUNCE
meta:pypi: $INCLUDE_PYPI
meta:first: $FIRST_FULL
$EXTRA_METADATA
"
    git tag -m "$TAGMSG" -s "$VERSION" $TARGETSHA
    git push gerrit $VERSION
fi

# We don't want to die just because we can't update some bug reports,
# so ignore failures.
set +e

BUGS=$(git log $PREVIOUS..$VERSION | egrep -i "Closes(.| )Bug:" | egrep -o "[0-9]+")
if [[ -z "$BUGS" ]]; then
    echo "No bugs found $PREVIOUS .. $VERSION"
else
    $TOOLSDIR/launchpad_add_comment.py \
        --subject="Fix included in $REPO $VERSION" \
        --content="This issue was fixed in the $REPO $VERSION $RELEASETYPE." \
        $BUGS
fi

# Try to propose a constraints update for libraries.
if [[ $INCLUDE_PYPI == "yes" ]]; then
    echo "Proposing constraints update"
    dist_name=$(python setup.py --name)
    if [[ -z "$dist_name" ]]; then
        echo "Could not determine the name of the constraint to update"
    else
        cd $MYTMPDIR
        clone_repo openstack/requirements stable/$SERIES
        cd openstack/requirements
        git checkout -b "$dist_name-$VERSION"
        sed -e "s/^${dist_name}=.*/$dist_name===$VERSION/" --in-place upper-constraints.txt
        git commit -a -m "update constraint for $dist_name to new release $VERSION

$TAGMSG
"
        git show
        git review -t 'new-release'
    fi
fi

exit 0
