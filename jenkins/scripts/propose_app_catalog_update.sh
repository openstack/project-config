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

source /usr/local/jenkins/slave_scripts/common.sh

PROJECT="openstack/app-catalog"
BRANCH="proposals"
INITIAL_COMMIT_MSG="Detect dead links"
TOPIC="detect-dead-links"
USERNAME="proposal-bot"
SUCCESS=0

setup_git

# Function setup_commit_message will set CHANGE_ID if a change
# exists and will always set COMMIT_MSG.
setup_commit_message $PROJECT $USERNAME $BRANCH $TOPIC "$INITIAL_COMMIT_MSG"

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
