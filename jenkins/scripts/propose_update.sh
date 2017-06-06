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
    VENV=$(mktemp -d)
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
    VENV=$(mktemp -d)
    trap "rm -rf $VENV" EXIT
    virtualenv $VENV
    $VENV/bin/pip install -e .
    function update {
        $VENV/bin/generate-constraints -b blacklist.txt -p /usr/bin/python2.7 \
            -p /usr/bin/python3 -r global-requirements.txt \
            --version-map 3.4:3.5 --version-map 3.5:3.4 \
            > $1/upper-constraints.txt
    }
elif [ "$OWN_PROJECT" == "devstack-plugins-list" ] ; then
    INITIAL_COMMIT_MSG="Updated from generate-devstack-plugins-list"
    TOPIC="openstack/devstack/plugins"
    PROJECTS=openstack-dev/devstack
    function update {
        bash -ex tools/generate-devstack-plugins-list.sh $1
    }
elif [ "$OWN_PROJECT" == "puppet-openstack-constraints" ] ; then
    INITIAL_COMMIT_MSG="Updated from Puppet OpenStack modules constraints"
    TOPIC="openstack/puppet/constraints"
    PROJECTS=openstack/puppet-openstack-integration
    function update {
        bash /usr/local/jenkins/slave_scripts/generate_puppetfile.sh
    }
elif [ "$OWN_PROJECT" == "openstack-ansible-tests" ] ; then
    INITIAL_COMMIT_MSG="Updated from OpenStack Ansible Tests"
    TOPIC="openstack/openstack-ansible-tests/sync-tests"
    ###### WIP - REMOVE ME #####
    # Use a single repository for testing
    PROJECTS="openstack/openstack-ansible-galera_client"
    ##### END OF WIP ########
    #PROJECTS=$(./gen-projects-list.sh)
    function update {
        bash /usr/local/jenkins/slave_scripts/sync_openstack_ansible_common_files.sh
    }
else
    echo "Unknown project $1" >2
    exit 1
fi
USERNAME="proposal-bot"
ALL_SUCCESS=0

if [ -z "$ZUUL_REFNAME" ] ; then
    echo "No ZUUL_REFNAME set, exiting."
    exit 1
fi

setup_git

for PROJECT in $PROJECTS; do

    PROJECT_DIR=$(basename $PROJECT)
    rm -rf $PROJECT_DIR

    # Don't short circuit when one project fails to clone, just report the
    # error and move onto the next project.
    #
    # TODO(fungi): switch to zuul-cloner once we add a persistent git cache
    # to proposal.slave.openstack.org
    if ! git clone git://git.openstack.org/$PROJECT.git; then
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

        # Function setup_commit_message will set CHANGE_ID if a change
        # exists and will always set COMMIT_MSG.
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
