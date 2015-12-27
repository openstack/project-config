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

# Setup git so that git review works
function setup_git {
    git config user.name "OpenStack Proposal Bot"
    git config user.email "openstack-infra@lists.openstack.org"
    git config gitreview.username "proposal-bot"

    # Initial state of repository is detached, create a branch to work
    # from. Otherwise git review will complain.
    git checkout -B proposals
}

# See if there is already open change. If so, get the change id for
# the existing change for use in the commit msg.
# Sets variable CHANGE_ID if there is a previous change.
# Sets variable COMMIT_MSG to include change id and INITIAL_COMMIT_MSG.
function setup_commit_message {
    local PROJECT=$1
    local USERNAME=$2
    local BRANCH=$3
    local TOPIC=$4
    local INITIAL_COMMIT_MSG=$5

    # See if there is an open change, if so, get the change id for the
    # existing change for use in the commit message.
    local change_info=$(ssh -p 29418 $USERNAME@review.openstack.org \
        gerrit query --current-patch-set status:open project:$PROJECT \
        owner:$USERNAME branch:$BRANCH topic:$TOPIC)
    local previous=$(echo "$change_info" | grep "^  number:" | awk '{print $2}')
    if [ -n "$previous" ]; then
        CHANGE_ID=$(echo "$change_info" | grep "^change" | awk '{print $2}')
        # read returns a non zero value when it reaches EOF. Because we use a
        # heredoc here it will always reach EOF and return a nonzero value.
        # Disable -e temporarily to get around the read.
        # The reason we use read is to allow for multiline variable content
        # and variable interpolation. Simply double quoting a string across
        # multiple lines removes the newlines.
        set +e
        read -d '' COMMIT_MSG <<EOF
$INITIAL_COMMIT_MSG

Change-Id: $change_id
EOF
        set -e
    else
        COMMIT_MSG=$INITIAL_COMMIT_MSG
    fi
}
