#!/bin/bash
#
# Script to update release notes in a repository when a new branch
# is created.
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

TOOLSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $TOOLSDIR/functions

SERIES=$1
REPO=$2

cd $REPO

NEW_BRANCH="stable/$SERIES"

commit_msg="Update reno for $NEW_BRANCH"
titlebranch=$(python -c "print('$SERIES'.title())")
cat - > releasenotes/source/${SERIES}.rst <<EOF
===================================
 $titlebranch Series Release Notes
===================================

.. release-notes::
   :branch: $NEW_BRANCH
EOF

# Look at the indentation of the existing entries and reuse the same
# depth.
spaces=$(grep unreleased releasenotes/source/index.rst | sed -e 's/\w//g')
# Insert the new release after the "unreleased" entry so the
# notes appear in reverse chronological order.
sed --in-place -e "/unreleased/s/unreleased/unreleased\n${spaces}${SERIES}/" releasenotes/source/index.rst
git add releasenotes/source/index.rst releasenotes/source/${SERIES}.rst
git diff
git commit -m "$commit_msg"
git show
git review -t "reno-${SERIES}" --yes
