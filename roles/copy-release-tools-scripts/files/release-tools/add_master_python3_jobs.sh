#!/bin/bash
#
# Script to update the zuul python3 jobs on master branch when a
# new series is created.
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

# As in 2023.1 cycle, we switch to using the generic template name to update
# the unit testing, we do not need this script after Zed release.
set -ex

if [[ $# -lt 3 ]]; then
    echo "Usage: $0 oldseries newseriesname repo_dir"
    echo
    echo "Example: $0 stein train openstack/oslo.config"
    exit 2
fi

OLDSERIES=$1
SERIES=$2
REPO=$3
TOOLSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# We only want the series name, make sure if a branch name is passed in that we
# strip out the part we don't want
OLDSERIES=${OLDSERIES/stable\//}

cd $REPO

commit_msg="Switch to 2023.1 Python3 unit tests and generic template name

This is an automatically generated patch to ensure unit testing
is in place for all the of the tested runtimes for ${SERIES}. Also,
updating the template name to generic one.

See also the PTI in governance [1].

[1]: https://governance.openstack.org/tc/reference/project-testing-interface.html
"

git checkout master
# Find the appropriate files
fnames=$(find . -type f -path '*zuul.d/*'; find . -type f -name '*zuul.yaml')
for fname in $fnames; do
    echo "Checking ${fname}"
    sed -i -e \
        "s/openstack-python3-${OLDSERIES}-jobs/openstack-python3-jobs/g" \
        $fname
done

# Only submit patch if files were changed
changes=$(git diff-index --name-only HEAD -- | grep zuul)
if [ -n "$changes" ]; then
    git checkout -b add-${SERIES}-python-jobtemplates

    # Add only the files we modified
    for file in $changes; do
        git add $file
    done
    git clean -f

    git diff --cached
    git commit -m "$commit_msg" || true
    git show
    git review --yes -f || true
fi
