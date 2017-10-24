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

TOOLSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $TOOLSDIR/functions

function usage {
    echo "Usage: release_from_yaml.sh [(-m|--manual)] releases_repository [deliverable_files]"
    echo "       release_from_yaml.sh (-h|--help)"
    echo
    echo "Example: release_from_yaml.sh -m ~/repos/openstack/releases"
    echo "Example: release_from_yaml.sh ~/repos/openstack/releases"
    echo "Example: release_from_yaml.sh -m ~/repos/openstack/releases deliverables/mitaka/oslo.config.yaml"
}

OPTS=$(getopt -o hm --long manual,help -n $0 -- "$@")
if [ $? != 0 ] ; then
    echo "Failed parsing options." >&2
    usage
    exit 1
fi
eval set -- "$OPTS"
set -x

BOT_RUNNING=true

while true; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -m|--manual)
            BOT_RUNNING=false
            shift
            ;;
        --)
            shift
            break
            ;;
    esac
done

if [ $# -lt 1 ]; then
    echo "ERROR: No releases_repository specified"
    echo
    usage
    exit 1
fi

RELEASES_REPO="$1"
shift
DELIVERABLES="$@"

setup_temp_space

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

RC=0

echo "Current state of $RELEASES_REPO"
(cd $RELEASES_REPO && git show)

echo "Changed files in the latest commit"
# This is the command list_deliverable_changes.py uses to figure out
# what files have been touched.
(cd $RELEASES_REPO && git diff --name-only --pretty=format: HEAD^)

change_list_file=$MYTMPDIR/change_list.txt

echo "Discovered deliverable updates"
$TOOLSDIR/list_deliverable_changes.py -r $RELEASES_REPO $DELIVERABLES | tee $change_list_file

echo "Starting tagging"
while read deliverable series version diff_start repo hash pypi first_full; do
    echo "$deliverable $series $version $diff_start $repo $hash $pypi $first_full"
    $TOOLSDIR/release.sh $repo $series $version $diff_start $hash $pypi $first_full "$RELEASE_META"
    RC=$(($RC + $?))
done < $change_list_file

exit $RC
