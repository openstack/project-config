#!/bin/bash -xe

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

PROJECT="openstack/app-catalog"
BRANCH="proposals"
INITIAL_COMMIT_MSG="Detect dead links"
TOPIC="detect-dead-links"
USERNAME="proposal-bot"
SUCCESS=0

setup_git

change_id=""
# See if there is an open change in the detect-dead-links topic
# If so, get the change id for the existing change for use in the
# commit msg.
change_info=$(ssh -p 29418 $USERNAME@review.openstack.org gerrit query --current-patch-set status:open project:$PROJECT topic:$TOPIC owner:$USERNAME)
previous=$(echo "$change_info" | grep "^  number:" | awk '{print $2}')
if [ -n "$previous" ]; then
    change_id=$(echo "$change_info" | grep "^change" | awk '{print $2}')
    # read return a non zero value when it reaches EOF. Because we use a
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

git review -s
python /usr/local/jenkins/slave_scripts/check_app_catalog_yaml.py

if ! git diff --stat --exit-code HEAD ; then
    # Commit and review
    git_args="-a -F-"
    git commit $git_args <<EOF
$COMMIT_MSG
EOF
    # Do error checking manually to ignore one class of failure.
    set +e
    OUTPUT=$(git review -t $TOPIC)
    RET=$?
    [[ "$RET" -eq "0" || "$OUTPUT" =~ "no new changes" || "$OUTPUT" =~ "no changes made" ]]
    SUCCESS=$?
fi

exit $SUCCESS
