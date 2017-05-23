#!/bin/bash -xe
#
# Copyright 2017, SUSE LINUX GmbH.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

# Copy common files from the openstack-ansible-tests repository
set -eu

OSA_PROJECT=${1}

# Careful of what you put here.
declare -ra files_to_sync=(run_tests.sh bindep.txt Vagrantfile tests/tests-repo-clone.sh)

excluded_projects=
exclude_project() {
    excluded_projects+="$1 "
}

# Always exclude openstack-ansible-tests repository. This is not
# necessary because OSA_PROJECT should never be "openstack-ansible-tests"
# but it can serve as an example for users who may add more
# projects in the future.
exclude_project "openstack-ansible-tests"

check_and_ignore() {
    for z in $(echo ${excluded_projects} | tr ' ' '\n'); do
        [[ $1 == $z ]] && return 0
    done
    return 1
}

for x in ${files_to_sync[@]}; do
    # If the target repo does not have such a file already
    # then it's probably best to leave it alone.
    [[ ! -e ${OSA_PROJECT}/${x} ]] && continue

    # Skip the project if it is in the excluded list
    check_and_ignore ${OSA_PROJECT} && continue

    # We don't preserve anything from the target repo.
    # We simply assume that all OSA projects need the same
    # $files_to_sync
    cp ${x} ${OSA_PROJECT}/${x}
done

exit 0
