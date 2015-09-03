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
SOFTWARE="Transifex"

if [ -n "$2" -a "$2" = "zanata" ]; then
    SOFTWARE="Zanata"
fi

source /usr/local/jenkins/slave_scripts/common_translation_update.sh

# Setup git repository for git review.
setup_git

# Check whether a review already exists, setup review commit message.
setup_review "$SOFTWARE"
# Setup basic connection for transifex.
setup_translation
# Project specific transifex setup.
setup_project "$PROJECT"

# Setup some global vars which will be used in the rest of the script.
setup_loglevel_vars
# Project specific transifex setup for log translations.
setup_loglevel_project "$PROJECT"

# Pull updated translations from Transifex, or Zanata.
case "$SOFTWARE" in
    Transifex)
        pull_from_transifex
        ;;
    Zanata)
        pull_from_zanata
        ;;
esac

# Extract all messages from project, including log messages.
extract_messages_log "$PROJECT"

# Update existing translation files with extracted messages.
PO_FILES=$(find ${PROJECT}/locale -name "${PROJECT}.po")
if [ -n "$PO_FILES" ]; then
    # Use updated .pot file to update translations
    python setup.py  $QUIET update_catalog \
        --no-fuzzy-matching --ignore-obsolete=true
fi
# We cannot run update_catalog for the log files, since there is no
# option to specify the keyword and thus an update_catalog run would
# add the messages with the default keywords. Therefore use msgmerge
# directly.
for level in $LEVELS ; do
    PO_FILES=$(find ${PROJECT}/locale -name "${PROJECT}-log-${level}.po")
    if [ -n "$PO_FILES" ]; then
        for f in $PO_FILES ; do
            echo "Updating $f"
            msgmerge --update --no-fuzzy-matching $f \
                --backup=none \
                ${PROJECT}/locale/${PROJECT}-log-${level}.pot
            # Remove obsolete entries
            msgattrib --no-obsolete --force-po \
                --output-file=${f}.tmp ${f}
            mv ${f}.tmp ${f}
        done
    fi
done

# Now add all changed files to git.
# Note we add them here to not have to differentiate in the functions
# between new files and files already under git control.
git add $PROJECT/locale/*

# Remove obsolete files.
cleanup_po_files "$PROJECT"

# Compress downloaded po files, this needs to be done after
# cleanup_po_files since that function needs to have information the
# number of untranslated strings.
compress_po_files "$PROJECT"

# Some files were changed, add changed files again to git, so that we
# can run git diff properly.
git add $PROJECT/locale/*

# Filter out commits we do not want.
filter_commits

# Propose patch to gerrit if there are changes.
send_patch
