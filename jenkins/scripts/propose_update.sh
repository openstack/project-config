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

OWN_PROJECT=$1
if [ -z "$OWN_PROJECT" ] ; then
    echo "usage: $0 project"
    exit 1
fi
if [ "$OWN_PROJECT" == "requirements" ] ; then
    INITIAL_COMMIT_MSG="Updated from global requirements"
    TOPIC="openstack/requirements"
    PROJECTS=$(cat projects.txt)
    VENV=$(mktemp)
    trap "rm -rf $VENV" EXIT
    virtualenv $VENV
    $VENV/bin/pip install -e .
    function update {
        $VENV/bin/update-requirements $1
    }
elif [ "$OWN_PROJECT" == "openstack-manuals" ] ; then
    INITIAL_COMMIT_MSG="Updated from openstack-manuals"
    TOPIC="openstack/openstack-manuals"
    PROJECTS=$(cat projects.txt)
    function update {
        bash -xe tools/sync-projects.sh $1
    }
elif [ "$OWN_PROJECT" == "requirements-constraints" ] ; then
    INITIAL_COMMIT_MSG="Updated from generate-constraints"
    TOPIC="openstack/requirements/constraints"
    PROJECTS=openstack/requirements
    VENV=$(mktemp)
    trap "rm -rf $VENV" EXIT
    virtualenv $VENV
    $VENV/bin/pip install -e .
    function update {
        $VENV/bin/generate-constraints -p /usr/bin/python2.7 \
            -p /usr/bin/python3.4 $1/global-requirements.txt \
            > $1/upper-constraints.txt
    }
else
    echo "Unknown project $1" >2
    exit 1
fi
USERNAME="proposal-bot"
ALL_SUCCESS=0

if [ -z "$ZUUL_REF" ] ; then
    echo "No ZUUL_REF set, exiting."
    exit 1
fi

setup_git

for PROJECT in $PROJECTS; do

    PROJECT_DIR=$(basename $PROJECT)
    rm -rf $PROJECT_DIR

    # Don't short circuit when one project fails to clone, just report the
    # error and move onto the next project.
    GIT_REPO="ssh://$USERNAME@review.openstack.org:29418/$PROJECT.git"
    if ! git clone $GIT_REPO; then
        # ALL_SUCCESS is being set to 1, which means that a failure condition
        # has been detected. The job will end in failure once it finishes
        # cycling through the remaining projects.
        ALL_SUCCESS=1
        echo "Error in git clone: Ignoring $PROJECT"
        continue
    fi
    pushd $PROJECT_DIR

    # check whether the project has this branch or a suitable fallback
    BRANCH=""
    if git branch -a | grep -q "^  remotes/origin/$ZUUL_REF$" ; then
        BRANCH=$ZUUL_REF
    elif echo $ZUUL_REF | grep -q "^stable/" ; then
        FALLBACK=$(echo $ZUUL_REF | sed s,^stable/,proposed/,)
        if git branch -a | grep -q "^  remotes/origin/$FALLBACK$" ; then
            BRANCH=$FALLBACK
        fi
    fi

    # don't bother with this project if there's not a usable branch
    if [ -n "$BRANCH" ] ; then
        change_id=""
        # See if there is an open change in the openstack/requirements topic
        # If so, get the change id for the existing change for use in the
        # commit msg.
        change_info=$(ssh -p 29418 $USERNAME@review.openstack.org gerrit query --current-patch-set status:open project:$PROJECT topic:$TOPIC owner:$USERNAME branch:$BRANCH)
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

        git checkout -B ${BRANCH} -t origin/${BRANCH}
        # Need to set the git config in each repo as we shouldn't
        # set it globally for the Jenkins user on the slaves.
        setup_git
        # Do error checking manually to continue with the next project
        # in case of failures like a broken .gitreview file.
        set +e
        git review -s
        RET=$?
        set -e
        popd
        if [ "$RET" -ne "0" ] ; then
            ALL_SUCCESS=1
            echo "Error in git review -s: Ignoring $PROJECT"
            continue
        fi

        # Don't short circuit when one project fails to sync.
        set +e
        update $PROJECT_DIR
        RET=$?
        set -e
        if [ "$RET" -ne "0" ] ; then
            ALL_SUCCESS=1
            echo "Error in syncing: Ignoring $PROJECT"
            continue
        fi

        pushd $PROJECT_DIR
        if ! git diff --stat --exit-code HEAD ; then
            # Commit and review
            git_args="-a -F-"
            git commit $git_args <<EOF
$COMMIT_MSG
EOF
            # Do error checking manually to ignore one class of failure.
            set +e
            OUTPUT=$(git review -t $TOPIC $BRANCH)
            RET=$?
            [[ "$RET" -eq "0" || "$OUTPUT" =~ "no new changes" || "$OUTPUT" =~ "no changes made" ]]
            SUCCESS=$?
            [[ "$SUCCESS" -eq "0" && "$ALL_SUCCESS" -eq "0" ]]
            ALL_SUCCESS=$?
            set -e
        fi
    fi

    popd
done

exit $ALL_SUCCESS
