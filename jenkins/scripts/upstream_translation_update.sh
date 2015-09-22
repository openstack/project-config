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

PROJECT=$1

if ! echo $ZUUL_REFNAME | grep master; then
    exit 0
fi

source /usr/local/jenkins/slave_scripts/common_translation_update.sh

setup_git

# Project setup and updating POT files.
case "$PROJECT" in
    api-site|ha-guide|openstack-manuals|operations-guide|security-doc)
        init_manuals "$PROJECT"
        # POT file extraction is done in setup_manuals.
        setup_manuals "$PROJECT"
        ;;
    django_openstack_auth)
        setup_django_openstack_auth
        extract_messages
        ;;
    horizon)
        setup_horizon
        ./run_tests.sh --makemessages -V
        ;;
    *)
        setup_project "$PROJECT"
        setup_loglevel_vars
        extract_messages
        extract_messages_log "$PROJECT"
        ;;
esac

# Add all changed files to git.
# Note that setup_manuals did the git add already, so we can skip it
# here.
if [[ ! $PROJECT =~ api-site|ha-guide|openstack-manuals|operations-guide|security-doc ]]; then
    git add */locale/*
fi

if [ $(git diff --cached | egrep -v "(POT-Creation-Date|^[\+\-]#|^\+{3}|^\-{3})" | egrep -c "^[\-\+]") -gt 0 ]; then
    # The Zanata client works out what to send based on the zanata.xml file.
    zanata-cli -B -e push
fi
