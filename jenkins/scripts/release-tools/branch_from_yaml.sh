#!/bin/bash
#
# Script to create stable branches based on changes to the
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

set -ex

TOOLSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $TOOLSDIR/functions

function usage {
    echo "Usage: branch_from_yaml.sh releases_repository series [deliverable_files]"
    echo
    echo "Example: branch_from_yaml.sh ~/repos/openstack/releases mitaka"
    echo "Example: branch_from_yaml.sh ~/repos/openstack/releases mitaka"
    echo "Example: branch_from_yaml.sh ~/repos/openstack/releases mitaka deliverables/mitaka/oslo.config.yaml"
}

if [ $# -lt 2 ]; then
    echo "ERROR: Please specify releases_repository and series"
    echo
    usage
    exit 1
fi

RELEASES_REPO="$1"
shift
SERIES="$1"
shift
DELIVERABLES="$@"

$TOOLSDIR/list_deliverable_changes.py -r $RELEASES_REPO $DELIVERABLES \
| while read deliverable series version diff_start repo hash announce_to pypi first_full; do
    echo "$SERIES $repo $version"
    $TOOLSDIR/make_stable_branch.sh $SERIES $repo $version
done

exit 0
