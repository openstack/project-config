#!/bin/bash
#
# Script to create branches for a project
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
set -x

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 repo_dir branch_name"
    echo
    echo "Example: $0 ../oslo.config stable/kilo"
    exit 2
fi

TOOLSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $TOOLSDIR/functions

REPO=$1
NEW_BRANCH=$2

cd $REPO
update_upper_constraints "$NEW_BRANCH"
