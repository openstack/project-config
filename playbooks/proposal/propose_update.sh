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

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPTSDIR/common.sh

OWN_PROJECT=$1
if [ -z "$OWN_PROJECT" ] ; then
    echo "usage: $0 project"
    exit 1
fi

if [ "$OWN_PROJECT" == "openstack-manuals" ] ; then
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
    tox -re venv --notest
    VENV=$(readlink -f .tox/venv)
    $VENV/bin/pip install -e .
    function update {
        $VENV/bin/generate-constraints -b blacklist.txt -p /usr/bin/python3.8 \
            -p /usr/bin/python3.9 \
            -r global-requirements.txt > $1/upper-constraints.txt
    }
elif [ "$OWN_PROJECT" == "devstack-plugins-list" ] ; then
    INITIAL_COMMIT_MSG="Updated from generate-devstack-plugins-list"
    TOPIC="openstack/devstack/plugins"
    PROJECTS=openstack/devstack
    function update {
        bash -ex tools/generate-devstack-plugins-list.sh $1
    }
elif [ "$OWN_PROJECT" == "puppet-openstack-constraints" ] ; then
    INITIAL_COMMIT_MSG="Updated from Puppet OpenStack modules constraints"
    TOPIC="openstack/puppet/constraints"
    PROJECTS=openstack/puppet-openstack-integration
    function update {
        bash /home/zuul/scripts/generate_puppetfile.sh
    }
elif [ "$OWN_PROJECT" == "openstack-ansible-tests" ] ; then
    INITIAL_COMMIT_MSG="Updated from OpenStack Ansible Tests"
    TOPIC="openstack/openstack-ansible-tests/sync-tests"
    PROJECTS=$(./gen-projects-list.sh)
    function update {
        bash /home/zuul/scripts/sync_openstack_ansible_common_files.sh $1
    }
elif [ "$OWN_PROJECT" == "os-service-types" ] ; then
    INITIAL_COMMIT_MSG="Updated from OpenStack Service Type Authority"
    TOPIC="openstack/os-service-types/sync-service-types-authority"
    PROJECTS="openstack/os-service-types"
    function update {
        pushd $1
        curl https://service-types.openstack.org/service-types.json > os_service_types/data/service-types.json
        popd
    }
else
    echo "Unknown project $1" >2
    exit 1
fi
USERNAME="proposal-bot"
ALL_SUCCESS=0

# In periodic pipelines, ZUUL_REFNAME is not set, use BRANCH_NAME
# instead here. The JJB scripts in v2 set always ZUUL_REFNAME, in v3
# we pass in the branch as additional parameter.
if [ -z "$ZUUL_REFNAME" ] ; then
    BRANCH_NAME=$2
    if [ -z "$BRANCH_NAME" ] ; then
        echo "usage: $0 project branch"
        exit 1
    fi
    ZUUL_REFNAME=$BRANCH_NAME
fi
# Zuul v3 adds refs/heads, remove that to get the branch
ZUUL_REFNAME=${ZUUL_REFNAME#refs/heads/}

setup_git

for PROJECT in $PROJECTS; do

    PROJECT_DIR=$(basename $PROJECT)
    rm -rf $PROJECT_DIR

    # Don't short circuit when one project fails to clone, just report the
    # error and move onto the next project.
    #
    # TODO(fungi): switch to zuul-cloner once we add a persistent git cache
    # to proposal.slave.openstack.org
    if ! git clone https://opendev.org/$PROJECT; then
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
    if git branch -a | grep -q "^  remotes/origin/$ZUUL_REFNAME$" ; then
        BRANCH=$ZUUL_REFNAME
    fi

    # don't bother with this project if there's not a usable branch
    if [ -n "$BRANCH" ] ; then

        # Function setup_commit_message will set CHANGE_ID and CHANGE_NUM if a
        # change exists and will always set COMMIT_MSG.
        setup_commit_message $PROJECT $USERNAME $BRANCH $TOPIC "$INITIAL_COMMIT_MSG"

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

        pushd $PROJECT_DIR
        # If a change already exists, let's pull it in and compute the
        # 'git patch-id' of it.
        PREV_PATCH_ID=""
        if [[ -n ${CHANGE_NUM} ]]; then
            # Ignore errors we get in case we can't download the patch with
            # git-review. If that happens then we will submit a new patch.
            set +e
            git review -d ${CHANGE_NUM}
            RET=$?
            if [[ "$RET" -eq 0 ]]; then
                PREV_PATCH_ID=$(git show | git patch-id | awk '{print $1}')
            fi
            set -e
            # The git review changed our branch, go back to our correct branch
            git checkout -f ${BRANCH}
        fi
        popd

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
            CUR_PATCH_ID=$(git show | git patch-id | awk '{print $1}')
            # Don't submit if we have the same patch id of previously submitted
            # patchset
            if [[ "${PREV_PATCH_ID}" != "${CUR_PATCH_ID}" ]]; then
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
    fi

    popd
done

exit $ALL_SUCCESS
