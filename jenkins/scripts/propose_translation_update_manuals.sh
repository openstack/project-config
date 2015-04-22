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

# Download new files.
# Also downloads updates for existing files that are
# translated to a certain amount as configured in setup_manuals.
# The function setup_manuals will setup most files --minimum-perc=75
# for most files.
tx pull -a -f

# Pull upstream translations of all downloaded files but do not
# download new files.
# Use lower percentage here to update the existing files.
tx pull -f --minimum-perc=50

# Compress downloaded po files
compress_po_files "doc"

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
