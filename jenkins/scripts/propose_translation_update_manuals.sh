#!/bin/bash -xe

# Copyright 2013 IBM Corp.
#
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

# The script is to pull the translations from Transifex,
# and push to Gerrit.

PROJECT=$1

source /usr/local/jenkins/slave_scripts/common_translation_update.sh

init_manuals "$PROJECT"

setup_git
setup_review
setup_translation

setup_manuals "$PROJECT"

# Pull updated translations from Zanata.
pull_from_zanata_manuals "$PROJECT"

# Compress downloaded po files
# Only touch glossary in openstack-manuals but not in any other
# repository.
case "$project" in
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

filter_commits

send_patch
