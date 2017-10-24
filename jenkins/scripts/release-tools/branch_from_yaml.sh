#!/bin/bash
#
# Script to create branches based on changes to the
# deliverables files in the openstack/releases repository.
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

set -x

TOOLSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $TOOLSDIR/functions

function usage {
    echo "Usage: branch_from_yaml.sh releases_repository [deliverable_files]"
    echo
    echo "Example: branch_from_yaml.sh ~/repos/openstack/releases"
    echo "Example: branch_from_yaml.sh ~/repos/openstack/releases"
    echo "Example: branch_from_yaml.sh ~/repos/openstack/releases deliverables/mitaka/oslo.config.yaml"
}

if [ $# -lt 1 ]; then
    echo "ERROR: Please specify releases_repository"
    echo
    usage
    exit 1
fi

RELEASES_REPO="$1"
shift
DELIVERABLES="$@"

setup_temp_space

echo "Current state of $RELEASES_REPO"
(cd $RELEASES_REPO && git show)

echo "Changed files in the latest commit"
# This is the command list_deliverable_branches.py uses to figure out
# what files have been touched.
(cd $RELEASES_REPO && git diff --name-only --pretty=format: HEAD^)

change_list_file=$MYTMPDIR/change_list.txt

echo "Discovered deliverable updates"
$TOOLSDIR/list_deliverable_branches.py -r $RELEASES_REPO $DELIVERABLES | tee $change_list_file

RC=0

while read repo branch ref; do
    echo "$repo $branch $ref"
    $TOOLSDIR/make_branch.sh $repo $branch $ref
    RC=$(($RC + $?))
done < $change_list_file

exit $RC
