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
    echo "Usage: release.sh [-a] repository series version diff_start SHA include_pypi first-full-release extra-metadata"
    echo
    echo "Example: release.sh openstack/oslo.rootwrap mitaka 3.0.3 '' gerrit/master yes no 'meta:release:Workflow+1: Doug Hellmann <doug@doughellmann.com>'"
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
INCLUDE_PYPI=${6:-no}
FIRST_FULL=${7:-no}
EXTRA_METADATA="$8"

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
    echo "$REPO already has a version $VERSION tag, skipping further processing"
    exit 0
else
    # WARNING(dhellmann): announce.sh expects to be able to parse this
    # commit message, so if you change the format you may have to
    # update announce.sh as well.
    TAGMSG="$SHORTNAME $VERSION $RELEASETYPE

meta:version: $VERSION
meta:diff-start: $DIFF_START
meta:series: $SERIES
meta:release-type: $RELEASETYPE
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
    python2 -u $TOOLSDIR/launchpad_add_comment.py \
        --subject="Fix included in $REPO $VERSION" \
        --content="This issue was fixed in the $REPO $VERSION $RELEASETYPE." \
        $BUGS
fi

exit 0
