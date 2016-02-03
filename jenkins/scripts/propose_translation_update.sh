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
BRANCH=$2
# Replace /'s in the branch name with -'s because Zanata does not
# allow /'s in version names.
ZANATA_VERSION=${BRANCH//\//-}

source /usr/local/jenkins/slave_scripts/common_translation_update.sh

# Propose updates for manuals
function propose_manuals {

    # Pull updated translations from Zanata.
    pull_from_zanata "$PROJECT"

    # Compress downloaded po files
    # Only touch glossary in openstack-manuals but not in any other
    # repository.
    case "$PROJECT" in
        openstack-manuals)
            compress_manual_po_files "doc" 1
            ;;
        api-site)
            compress_manual_po_files "api-ref-guides" 0
            compress_manual_po_files "api-quick-start" 0
            compress_manual_po_files "api-ref" 0
            compress_manual_po_files "openstack-firstapp" 0
            ;;
        ha-guide|operations-guide)
            compress_manual_po_files "doc" 0
            ;;
        security-doc)
            compress_manual_po_files "security-guide" 0
            ;;
    esac

    # Add imported upstream translations to git
    for FILE in ${DocFolder}/*; do
        DOCNAME=${FILE#${DocFolder}/}
        if [ -d ${DocFolder}/${DOCNAME}/locale ] ; then
            git add ${DocFolder}/${DOCNAME}/locale/*
        fi
        if [ -d ${DocFolder}/${DOCNAME}/source/locale ] ; then
            git add ${DocFolder}/${DOCNAME}/source/locale/*
        fi
    done
}

# Propose updates for training-guides
function propose_training_guides {

    # Pull updated translations from Zanata.
    pull_from_zanata "$PROJECT"

    # Compress downloaded po files
    compress_po_files "doc/upstream-training"

    # Add all changed files to git
    git add doc/upstream-training/source/locale/*
}

# Propose updates for python projects
function propose_python {
    local project=$1
    local modulename=$2

    # Pull updated translations from Zanata
    pull_from_zanata "$project"

    # Extract all messages from project, including log messages.
    extract_messages "$modulename"
    extract_messages_log "$modulename"

    # Now add all changed files to git.
    # Note we add them here to not have to differentiate in the functions
    # between new files and files already under git control.
    git add $modulename/locale/*

    # Remove obsolete files.
    cleanup_po_files "$modulename"

    # Compress downloaded po files, this needs to be done after
    # cleanup_po_files since that function needs to have information the
    # number of untranslated strings.
    compress_po_files "$modulename"

    # Some files were changed, add changed files again to git, so that we
    # can run git diff properly.
    git add $modulename/locale/*
}

function propose_horizon {

    # Pull updated translations from Zanata.
    pull_from_zanata "$PROJECT"

    # Invoke run_tests.sh to update the po files
    # Or else, "../manage.py makemessages" can be used.
    ./run_tests.sh --makemessages -V

    # Compress downloaded po files
    compress_po_files "horizon"
    compress_po_files "openstack_dashboard"

    # Add all changed files to git
    git add horizon/locale/* openstack_dashboard/locale/*
}

# This function can be used for all django projects
function propose_django {
    local project=$1
    local modulename=$2
    # Pull updated translations from Zanata.
    pull_from_zanata "$project"

    # Update the .pot file
    extract_messages_django "$modulename"

    # Compress downloaded po files
    compress_po_files "$modulename"

    # Add all changed files to git
    git add $modulename/locale/*
}

# Setup git repository for git review.
setup_git

# Check whether a review already exists, setup review commit message.
setup_review "$BRANCH"

case "$PROJECT" in
    api-site|ha-guide|openstack-manuals|operations-guide|security-doc)
        init_manuals "$PROJECT"
        setup_manuals "$PROJECT" "$ZANATA_VERSION"
        propose_manuals
        ;;
    training-guides)
        setup_training_guides "$ZANATA_VERSION"
        propose_training_guides
        ;;
    horizon)
        setup_horizon "$ZANATA_VERSION"
        propose_horizon
        ;;
    *)
        # Common setup for python and django repositories
        # ---- Python projects ----
        MODULENAME=$(get_modulename $PROJECT python)
        if [ -n "$MODULENAME" ]; then
            setup_project "$PROJECT" "$MODULENAME" "$ZANATA_VERSION"
            setup_loglevel_vars
            propose_python "$PROJECT" "$MODULENAME"
        fi

        # ---- Django projects ----
        MODULENAME=$(get_modulename $PROJECT django)
        if [ -n "$MODULENAME" ]; then
            setup_project "$PROJECT" "$MODULENAME" "$ZANATA_VERSION"
            propose_django "$PROJECT" "$MODULENAME"
        fi
        ;;
esac

# Filter out commits we do not want.
filter_commits

# Propose patch to gerrit if there are changes.
send_patch "$BRANCH"

if [ $INVALID_PO_FILE -eq 1 ] ; then
    echo "At least one po file in invalid. Fix all invalid files on the"
    echo "translation server."
    exit 1
fi
