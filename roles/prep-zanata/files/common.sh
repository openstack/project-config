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

# Setup git so that git review works:
# * git review set up is done as part of the playbooks
# * Set up a branch in case the repo started with a detached head.
function setup_git {

    # Initial state of repository is detached, create a branch to work
    # from. Otherwise git review will complain.
    git checkout -B proposals
}

# See if there is already open change. If so, get the change id for
# the existing change for use in the commit msg.
# Sets the variables CHANGE_ID and CHANGE_NUM if there is a previous change.
# Sets variable COMMIT_MSG to include change id and INITIAL_COMMIT_MSG.
function setup_commit_message {
    local PROJECT=$1
    local USERNAME=$2
    local BRANCH=$3
    local TOPIC=$4
    local INITIAL_COMMIT_MSG=$5

    # Clear any old values
    CHANGE_ID=""
    # CHANGE_NUM will be the change number (for example 519105)
    CHANGE_NUM=""
    # See if there is an open change, if so, get the change id for the
    # existing change for use in the commit message.
    local change_info=$(ssh -p 29418 $USERNAME@review.openstack.org \
        gerrit query --current-patch-set status:open project:$PROJECT \
        owner:$USERNAME branch:$BRANCH topic:$TOPIC)
    CHANGE_NUM=$(echo "$change_info" | grep "^  number:" | awk '{print $2}')
    if [ -n "$CHANGE_NUM" ]; then
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

Change-Id: $CHANGE_ID
EOF
        set -e
    else
        COMMIT_MSG=$INITIAL_COMMIT_MSG
    fi
}

# Check to see if $CHANGE_ID is already approved, if it is, don't bother
# proposing another.
function check_already_approved {
    local CHANGE_ID=$1

    # If the open change an already approved, let's not queue a new
    # patch but let's merge the other patch first.
    # This solves the problem that when the gate pipeline backup
    # reaches roughly a day, no matter how quickly you approve the new
    # update it will always get sniped out of the gate by another.
    # It also helps, when you approve close to the time this job is
    # run.
    if [ -n "$CHANGE_ID" ]; then
        # Use the JSON format since it is very compact and easy to grep
        change_info=$(ssh -p 29418 proposal-bot@review.openstack.org gerrit query --current-patch-set --format=JSON $CHANGE_ID)
        # Check for:
        # 1) Workflow approval (+1)
        # 2) no -1/-2 by Zuul
        # 3) no -2 by reviewers
        # 4) no Workflow -1 (WIP)
        #
        if echo $change_info|grep -q '{"type":"Workflow","description":"Workflow","value":"1"' \
            && ! echo $change_info|grep -q '{"type":"Verified","description":"Verified","value":"-[12]","grantedOn":[0-9]*,"by":{"name":"Zuul","username":"zuul"}}'  \
            && ! echo $change_info|grep -q '{"type":"Code-Review","description":"Code-Review","value":"-2"' \
            && ! echo $change_info|grep -q '{"type":"Workflow","description":"Workflow","value":"-1"' ; then
            echo "Job already approved, exiting"
            exit 0
        fi
    fi
}
