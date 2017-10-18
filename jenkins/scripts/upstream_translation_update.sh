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
JOBNAME=$2

# Replace /'s in branch names with -'s because Zanata doesn't
# allow /'s in version names.
ZANATA_VERSION=${ZUUL_REFNAME//\//-}

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPTSDIR/common_translation_update.sh

init_branch $ZUUL_REFNAME

# List of all modules to copy POT files from
ALL_MODULES=""

# Setup venv - needed for all projects for subunit and also
# for our own python tools.
setup_venv

if ! $VENV/bin/python $SCRIPTSDIR/query-zanata-project-version.py \
    -p $PROJECT -v $ZANATA_VERSION; then
    # Exit successfully so that lack of a version doesn't cause the jenkins
    # jobs to fail. This is necessary because not all branches of a project
    # will be translated.

    # Tell finish function that everything is fine.
    ERROR_ABORT=0
    exit 0
fi

setup_git

# Project setup and updating POT files.
case "$PROJECT" in
    api-site|openstack-manuals|security-doc)
        init_manuals "$PROJECT"
        # POT file extraction is done in setup_manuals.
        setup_manuals "$PROJECT" "$ZANATA_VERSION"
        case "$PROJECT" in
            api-site)
                ALL_MODULES="api-quick-start firstapp"
                ;;
            security-doc)
                ALL_MODULES="security-guide"
                ;;
            *)
                ALL_MODULES="doc"
                ;;
        esac
        if [[ "$ZANATA_VERSION" == "master" && -f releasenotes/source/conf.py ]]; then
            extract_messages_releasenotes
            ALL_MODULES="releasenotes $ALL_MODULES"
        fi
        ;;
    training-guides)
        setup_training_guides "$ZANATA_VERSION"
        ALL_MODULES="doc"
        ;;
    i18n)
        setup_i18n "$ZANATA_VERSION"
        ALL_MODULES="doc"
        ;;
    tripleo-ui)
        setup_reactjs_project "$PROJECT" "$ZANATA_VERSION"
        # The pot file is generated in the ./i18n directory
        ALL_MODULES="i18n"
        ;;
    *)
        # Common setup for python and django repositories
        # ---- Python projects ----
        module_names=$(get_modulename $PROJECT python)
        if [ -n "$module_names" ]; then
            setup_project "$PROJECT" "$ZANATA_VERSION" $module_names
            if [[ "$ZANATA_VERSION" == "master" && -f releasenotes/source/conf.py ]]; then
                extract_messages_releasenotes
                ALL_MODULES="releasenotes $ALL_MODULES"
            fi
            for modulename in $module_names; do
                extract_messages_python "$modulename"
                ALL_MODULES="$modulename $ALL_MODULES"
            done
        fi

        # ---- Django projects ----
        module_names=$(get_modulename $PROJECT django)
        if [ -n "$module_names" ]; then
            setup_project "$PROJECT" "$ZANATA_VERSION" $module_names
            install_horizon
            if [[ "$ZANATA_VERSION" == "master" && -f releasenotes/source/conf.py ]]; then
                extract_messages_releasenotes
                ALL_MODULES="releasenotes $ALL_MODULES"
            fi
            for modulename in $module_names; do
                extract_messages_django "$modulename"
                ALL_MODULES="$modulename $ALL_MODULES"
            done
        fi
        ;;
esac

# The Zanata client works out what to send based on the zanata.xml file.
# Do not copy translations from other files for this change.
zanata-cli -B -e push --copy-trans False
# Move pot files to translation-source directory for publishing
copy_pot "$ALL_MODULES"

mv .translation-source translation-source

# Tell finish function that everything is fine.
ERROR_ABORT=0
