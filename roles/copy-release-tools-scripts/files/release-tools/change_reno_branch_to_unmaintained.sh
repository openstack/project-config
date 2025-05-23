#!/bin/bash
#
# Script to update release notes in a repository when a stable/<series>
# branch transitions to unmaintained.
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

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 series repo_dir"
    echo
    echo "Example: $0 kilo openstack/oslo.config"
    exit 2
fi

SERIES=$1
REPO=$2

cd $REPO

if [[ ! -f releasenotes/source/${SERIES}.rst ]]; then
    echo "No releasenotes source defined for series ${SERIES}, nothing to update."
    exit 0
fi

commit_msg="reno: Update master for unmaintained/${SERIES}

Update the ${SERIES} release notes configuration to build from
unmaintained/${SERIES}.
"

sed --in-place -e "s/stable\/${SERIES}/unmaintained\/${SERIES}/" releasenotes/source/${SERIES}.rst
git add releasenotes/source/${SERIES}.rst
git diff
git commit -m "$commit_msg" -s \
    --trailer="Generated-By:openstack/project-config:roles/copy-release-tools-scripts/files/release-tools/change_reno_branch_to_unmaintained.sh"
git show
git review -t "reno-eom-${SERIES}" --yes
