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

# Replace /'s in branch names with -'s because Zanata doesn't
# allow /'s in version names.
ZANATA_VERSION=${ZUUL_REFNAME//\//-}

source /usr/local/jenkins/slave_scripts/common_translation_update.sh

if ! /usr/local/jenkins/slave_scripts/query-zanata-project-version.py \
    -p $PROJECT -v $ZANATA_VERSION; then
    # Exit successfully so that lack of a version doesn't cause the jenkins
    # jobs to fail. This is necessary because not all branches of a project
    # will be translated.
    exit 0
fi

setup_git

# Project setup and updating POT files.
case "$PROJECT" in
    api-site|ha-guide|openstack-manuals|operations-guide|security-doc)
        init_manuals "$PROJECT"
        # POT file extraction is done in setup_manuals.
        setup_manuals "$PROJECT" "$ZANATA_VERSION"
        if [[ "$ZANATA_VERSION" == "master" && -f releasenotes/source/conf.py ]]; then
            extract_messages_releasenotes
        fi
        ;;
    training-guides)
        setup_training_guides "$ZANATA_VERSION"
        ;;
    *)
        # Common setup for python and django repositories
        setup_venv
        # ---- Python projects ----
        module_names=$(get_modulename $PROJECT python)
        if [ -n "$module_names" ]; then
            setup_project "$PROJECT" "$ZANATA_VERSION" $module_names
            setup_loglevel_vars
            if [[ "$ZANATA_VERSION" == "master" && -f releasenotes/source/conf.py ]]; then
                extract_messages_releasenotes
            fi
            for modulename in $module_names; do
                extract_messages_python "$modulename"
            done
        fi

        # ---- Django projects ----
        module_names=$(get_modulename $PROJECT django)
        if [ -n "$module_names" ]; then
            setup_project "$PROJECT" "$ZANATA_VERSION" $module_names
            install_horizon
            if [[ "$ZANATA_VERSION" == "master" && -f releasenotes/source/conf.py ]]; then
                extract_messages_releasenotes
            fi
            for modulename in $module_names; do
                extract_messages_django "$modulename"
            done
        fi
        ;;
esac

# Add all changed files to git.
# Note that setup_manuals did the git add already, so we can skip it
# here.
if [[ ! $PROJECT =~ api-site|ha-guide|openstack-manuals|operations-guide|security-doc ]]; then
    git add */locale/*
fi
if [ -d releasenotes/source/locale ] ; then
    git add releasenotes/source/locale
fi

if [ $(git diff --cached | egrep -v "(POT-Creation-Date|^[\+\-]#|^\+{3}|^\-{3})" | egrep -c "^[\-\+]") -gt 0 ]; then
    # First, delete our VENV, otherwise the Zanata client might push some
    # extra files.
    if [ "$VENV" != "" ] ; then
        rm -rf $VENV
    fi
    # The Zanata client works out what to send based on the zanata.xml file.
    # Do not copy translations from other files for this change.
    zanata-cli -B -e push --copy-trans False
    # Copy all *.pot files to pot-files directory
    mkdir -p .pot-files/$ZANATA_VERSION/
    # Exclude . directories
    find . -path "./.*" -prune -o -name "*.pot" -exec cp -v {} .pot-files \;
    mv .pot-files pot-files
fi
