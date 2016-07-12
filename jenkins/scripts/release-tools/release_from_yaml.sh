#!/bin/bash
#
# Script to release projects based on changes to the deliverables
# files in the openstack/releases repository.
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

TOOLSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $TOOLSDIR/functions

function usage {
    echo "Usage: release_from_yaml.sh releases_repository [deliverable_files]"
    echo
    echo "Example: release_from_yaml.sh ~/repos/openstack/releases"
    echo "Example: release_from_yaml.sh ~/repos/openstack/releases"
    echo "Example: release_from_yaml.sh ~/repos/openstack/releases deliverables/mitaka/oslo.config.yaml"
}

if [ $# -lt 1 ]; then
    echo "ERROR: No releases_repository specified"
    echo
    usage
    exit 1
fi

RELEASES_REPO="$1"
shift
DELIVERABLES="$@"

# Configure git to pull the notes where gerrit stores review history
# like who approved a patch.
cd $RELEASES_REPO
if ! git config --get remote.origin.fetch | grep -q refs/notes/review; then
    git config --add remote.origin.fetch refs/notes/review:refs/notes/review
    git config --add core.notesRef refs/notes/review
    git remote update origin
fi

# Look for metadata about the release instructions to include in the
# tag message.
if git show --no-patch --pretty=format:%P | grep -q ' '; then
    # multiple parents, look at the submitted patch instead of the
    # merge commit
    parent=$(git show --no-patch --pretty=format:%P | cut -f2 -d' ')
else
    # single parent, look at the current patch
    parent=''
fi
RELEASE_META=$(git show --format=full --show-notes=review $parent | egrep -i '(Author|Commit:|Code-Review|Workflow|Change-Id)' | sed -e 's/^    //g' -e 's/^/meta:release:/g')

$TOOLSDIR/list_deliverable_changes.py -r $RELEASES_REPO $DELIVERABLES \
| while read deliverable series version repo hash announce_to pypi first_full; do
    title "$repo $series $version $hash $announce_to"
    # FIXME(dhellmann): While we work out the kinks in the job, we
    # only want to actually apply the tags to the release-test
    # repository. When we're confident that it is working correctly,
    # we can remove this block and apply it to all repositories.
    if [ "$repo" != "openstack/release-test" ]; then
        echo "SKIPPING during testing phase"
        continue
    fi
    $TOOLSDIR/release.sh $repo $series $version $hash $announce_to $pypi $first_full "$RELEASE_META"
done

exit 0
