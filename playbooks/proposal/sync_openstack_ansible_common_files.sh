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

# Copy common files from the openstack-ansible repository
set -eu

OSA_PROJECT=${1}

# Careful of what you put here.
declare -ra files_to_sync=(run_tests.sh bindep.txt Vagrantfile .gitignore sync/doc/* sync/tasks/*)

excluded_projects=
exclude_project() {
    excluded_projects+="$1 "
}

# Always exclude openstack-ansible repository. This is not
# necessary because OSA_PROJECT should never be "openstack-ansible"
# but it can serve as an example for users who may add more
# projects in the future.
exclude_project "openstack-ansible"

check_and_ignore() {
    for z in $(echo ${excluded_projects} | tr ' ' '\n'); do
        [[ $1 == $z ]] && return 0
    done
    return 1
}

for src_path in ${files_to_sync[@]}; do
    # If the source repo does not have the file to copy
    # then skip to the next file. This covers the situation
    # where this script runs against old branches which
    # do not have the same set of files. If the src_path
    # is 'sync/tasks/*' because the folder does not exist
    # then it will fail this test too.
    [[ ! -e ${src_path} ]] && continue

    # For the sync/* files in the array, the destination
    # path is different to the source path. To work out
    # the destination path we remove the 'sync/' prefix.
    dst_path=${src_path#sync/}

    # If the target repo does not have such a file already
    # then it's probably best to leave it alone.
    [[ ! -e ${OSA_PROJECT}/${dst_path} ]] && continue

    # Skip the project if it is in the excluded list
    check_and_ignore ${OSA_PROJECT} && continue

    # We don't preserve anything from the target repo.
    # We simply assume that all OSA projects need the same
    # $files_to_sync
    cp ${src_path} ${OSA_PROJECT}/${dst_path}
done

exit 0
