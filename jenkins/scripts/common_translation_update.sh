#!/bin/bash -xe
# Common code used by propose_translation_update.sh and
# upstream_translation_update.sh

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

# Used for setup.py babel commands
QUIET="--quiet"

# Setup a project for Zanata
function setup_project {
    local project=$1
    local version=${2:-master}

    /usr/local/jenkins/slave_scripts/create-zanata-xml.py -p $project \
        -v $version --srcdir ${project}/locale --txdir ${project}/locale \
        -f zanata.xml
}

# Setup project horizon for Zanata
function setup_horizon {
    local project=horizon
    local version=${1:-master}

    /usr/local/jenkins/slave_scripts/create-zanata-xml.py -p $project \
        -v $version --srcdir . --txdir . -r './horizon/locale/*.pot' \
        'horizon/locale/{locale_with_underscore}/LC_MESSAGES/{filename}.po' \
        -r './openstack_dashboard/locale/*.pot' \
        'openstack_dashboard/locale/{locale_with_underscore}/LC_MESSAGES/{filename}.po' \
        -e '.*/**' -f zanata.xml
}

# Set global variable DocFolder for manuals projects
function init_manuals {
    project=$1

    DocFolder="doc"
    ZanataDocFolder="./doc"
    if [ $project = "api-site" -o $project = "security-doc" ] ; then
        DocFolder="./"
        ZanataDocFolder="."
    fi
}

# Setup project manuals projects (api-site, openstack-manuals,
# operations-guide) for Zanata
function setup_manuals {
    local project=$1
    local version=${2:-master}

    # Fill in associative array SPECIAL_BOOKS
    declare -A SPECIAL_BOOKS
    source doc-tools-check-languages.conf

    # Grab all of the rules for the documents we care about
    ZANATA_RULES=

    # Generate pot one by one
    for FILE in ${DocFolder}/*; do
        # Skip non-directories
        if [ ! -d $FILE ]; then
            continue
        fi
        DOCNAME=${FILE#${DocFolder}/}
        # Ignore directories that will not get translated
        if [[ "$DOCNAME" =~ ^(www|tools|generated|publish-docs)$ ]]; then
            continue
        fi
        # Skip glossary in all repos besides openstack-manuals.
        if [ "$project" != "openstack-manuals" -a "$DOCNAME" == "glossary" ]; then
            continue
        fi
        # Minimum amount of translation done, 75 % by default.
        PERC=75
        if [ "$project" == "openstack-manuals" ]; then
            # The common and glossary directories are used by the
            # other guides, let's be more liberal here since teams
            # might only translate the files used by a single
            # guide. We use 8 % since that downloads the currently
            # translated files.
            if [ "$DOCNAME" == "common" -o "$DOCNAME" == "glossary" ]; then
                PERC=8
            fi
        fi
        IS_RST=0
        if [ ${SPECIAL_BOOKS["${DOCNAME}"]+_} ] ; then
            case "${SPECIAL_BOOKS["${DOCNAME}"]}" in
                RST)
                    IS_RST=1
                    ;;
                skip)
                    continue
                    ;;
            esac
        fi
        if [ ${IS_RST} -eq 1 ] ; then
            tox -e generatepot-rst -- ${DOCNAME}
            git add ${DocFolder}/${DOCNAME}/source/locale/${DOCNAME}.pot
            ZANATA_RULES="$ZANATA_RULES -r ${ZanataDocFolder}/${DOCNAME}/source/locale/${DOCNAME}.pot ${DocFolder}/${DOCNAME}/source/locale/{locale_with_underscore}/LC_MESSAGES/${DOCNAME}.po"
        else
            # Update the .pot file
            ./tools/generatepot ${DOCNAME}
            if [ -f ${DocFolder}/${DOCNAME}/locale/${DOCNAME}.pot ]; then
                # Add all changed files to git
                git add ${DocFolder}/${DOCNAME}/locale/${DOCNAME}.pot
                ZANATA_RULES="$ZANATA_RULES -r ${ZanataDocFolder}/${DOCNAME}/locale/${DOCNAME}.pot ${DocFolder}/${DOCNAME}/locale/{locale_with_underscore}.po"
            fi
        fi
    done
    if [ "$project" == "openstack-manuals" ]; then
        EXCLUDE='.*/**,**/source/common/**'
    else
        EXCLUDE='.*/**,**/source/common/**,**/glossary/**'
    fi
    /usr/local/jenkins/slave_scripts/create-zanata-xml.py -p $project \
        -v $version --srcdir . --txdir . $ZANATA_RULES -e "$EXCLUDE" \
        -f zanata.xml
}

# Setup project so that git review works, sets global variable
# COMMIT_MSG.
function setup_review {
    # Note we cannot rely on the default branch in .gitreview being
    # correct so we are very explicit here.
    local branch=${1:-master}
    FULL_PROJECT=$(grep project .gitreview  | cut -f2 -d= |sed -e 's/\.git$//')
    set +e
    read -d '' COMMIT_MSG <<EOF
Imported Translations from Zanata

For more information about this automatic import see:
https://wiki.openstack.org/wiki/Translations/Infrastructure
EOF
    set -e
    git review -s

    # See if there is an open change in the zanata/translations
    # topic. If so, get the change id for the existing change for use
    # in the commit msg.
    change_info=$(ssh -p 29418 proposal-bot@review.openstack.org gerrit query --current-patch-set status:open project:$FULL_PROJECT branch:$branch topic:zanata/translations owner:proposal-bot)
    previous=$(echo "$change_info" | grep "^  number:" | awk '{print $2}')
    if [ -n "$previous" ]; then
        change_id=$(echo "$change_info" | grep "^change" | awk '{print $2}')
        # Read returns a non zero value when it reaches EOF. Because we use a
        # heredoc here it will always reach EOF and return a nonzero value.
        # Disable -e temporarily to get around the read.
        set +e
        read -d '' COMMIT_MSG <<EOF
$COMMIT_MSG

Change-Id: $change_id
EOF
        set -e
    fi
    # If the open change an already approved, let's not queue a new
    # patch but let's merge the other patch first.
    # This solves the problem that when the gate pipeline backup
    # reaches roughly a day, no matter how quickly you approve the new
    # update it will always get sniped out of the gate by another.
    # It also helps, when you approve close to the time this job is
    # run.
    if [ -n "$previous" ]; then
        # Use the JSON format since it is very compact and easy to grep
        change_info=$(ssh -p 29418 proposal-bot@review.openstack.org gerrit query --current-patch-set --format=JSON $change_id)
        # Check for:
        # 1) Workflow approval (+1)
        # 2) no -1/-2 by Jenkins
        # 3) no -2 by reviewers
        # 4) no Workflow -1 (WIP)
        #
        if echo $change_info|grep -q '{"type":"Workflow","description":"Workflow","value":"1"' \
            && ! echo $change_info|grep -q '{"type":"Verified","description":"Verified","value":"-[12]","grantedOn":[0-9]*,"by":{"name":"Jenkins","username":"jenkins"}}'  \
            && ! echo $change_info|grep -q '{"type":"Code-Review","description":"Code-Review","value":"-2"' \
            && ! echo $change_info|grep -q '{"type":"Workflow","description":"Workflow","value":"-1"' ; then
            echo "Job already approved, exiting"
            exit 0
        fi
    fi
}

# Propose patch using COMMIT_MSG
function send_patch {
    local branch=${1:-master}

    # We don't have any repos storing zanata.xml, so just remove it.
    rm -f zanata.xml

    # Don't send a review if nothing has changed.
    if [ $(git diff --cached | wc -l) -gt 0 ]; then
        # Commit and review
        git commit -F- <<EOF
$COMMIT_MSG
EOF
        # We cannot rely on the default branch in .gitreview being
        # correct so we are very explicit here.
        git review -t zanata/translations $branch

    fi
}

# Setup global variables LEVELS and LKEYWORDS
function setup_loglevel_vars {
    # Strings for various log levels
    LEVELS="info warning error critical"
    # Keywords for each log level:
    declare -g -A LKEYWORD
    LKEYWORD['info']='_LI'
    LKEYWORD['warning']='_LW'
    LKEYWORD['error']='_LE'
    LKEYWORD['critical']='_LC'
}

# Run extract_messages for user visible messages.
function extract_messages {

    # Update the .pot files
    # The "_C" and "_P" prefix are for more-gettext-support blueprint,
    # "_C" for message with context, "_P" for plural form message.
    python setup.py $QUIET extract_messages --keyword "_C:1c,2 _P:1,2"
}

# Run extract_messages for log messages.
# Needs variables setup via setup_loglevel_vars.
function extract_messages_log {
    project=$1

    # Update the .pot files
    for level in $LEVELS ; do
        python setup.py $QUIET extract_messages --no-default-keywords \
            --keyword ${LKEYWORD[$level]} \
            --output-file ${project}/locale/${project}-log-${level}.pot
    done
}

# Setup project django_openstack_auth for Zanata
function setup_django_openstack_auth {
    local project=django_openstack_auth
    local version=${1:-master}

    /usr/local/jenkins/slave_scripts/create-zanata-xml.py \
        -p $project -v $version --srcdir openstack_auth/locale \
        --txdir openstack_auth/locale -r '**/*.pot' \
        '{locale_with_underscore}/LC_MESSAGES/django.po' -f zanata.xml
}

# Filter out files that we do not want to commit
function filter_commits {
    # Don't add new empty files.
    for f in $(git diff --cached --name-only --diff-filter=A); do
        # Files should have at least one non-empty msgid string.
        if ! grep -q 'msgid "[^"]' "$f" ; then
            git reset -q "$f"
            rm "$f"
        fi
    done

    # Don't send files where the only things which have changed are
    # the creation date, the version number, the revision date,
    # name of last translator, comment lines, or diff file information.
    # Also, don't send files if only .pot files would be changed.
    PO_CHANGE=0
    # Don't iterate over deleted files
    for f in $(git diff --cached --name-only --diff-filter=AM); do
        # It's ok if the grep fails
        set +e
        REGEX="(POT-Creation-Date|Project-Id-Version|PO-Revision-Date|Last-Translator|X-Generator)"
        changed=$(git diff --cached "$f" \
            | egrep -v "$REGEX" \
            | egrep -c "^([-+][^-+#])")
        added=$(git diff --cached "$f" \
            | egrep -v "$REGEX" \
            | egrep -c "^([+][^+#])")
        set -e
        if [ $changed -eq 0 ]; then
            git reset -q "$f"
            git checkout -- "$f"
        # Check for all files endig with ".po".
        # We will take this import if at least one change adds new content,
        # thus adding a new translation.
        # If only lines are removed, we do not need this.
        elif [[ $added -gt 0 && $f =~ .po$ ]] ; then
            PO_CHANGE=1
        fi
    done
    # If no po file was changed, only pot source files were changed
    # and those changes can be ignored as they give no benefit on
    # their own.
    if [ $PO_CHANGE -eq 0 ] ; then
        # New files need to be handled differently
        for f in $(git diff --cached --name-only --diff-filter=A) ; do
            git reset -q -- "$f"
            rm "$f"
        done
        for f in $(git diff --cached --name-only) ; do
            git reset -q -- "$f"
            git checkout -- "$f"
        done
    fi
}

# Check the amount of translation done for a .po file, sets global variable
# RATIO.
function check_po_file {
    local file=$1
    local dropped_ratio=$2

    trans=$(msgfmt --statistics -o /dev/null "$file" 2>&1)
    check="^0 translated messages"
    if [[ $trans =~ $check ]] ; then
        RATIO=0
    else
        if [[ $trans =~ " translated message" ]] ; then
            trans_no=$(echo $trans|sed -e 's/ translated message.*$//')
        else
            trans_no=0
        fi
        if [[ $trans =~ " untranslated message" ]] ; then
            untrans_no=$(echo $trans|sed -e 's/^.* \([0-9]*\) untranslated message.*/\1/')
        else
            untrans_no=0
        fi
        total=$(($trans_no+$untrans_no))
        RATIO=$((100*$trans_no/$total))
    fi
}

# Remove obsolete files. We might have added them in the past but
# would not add them today, so let's eventually remove them.
function cleanup_po_files {
    local project=$1

    for i in $(find $project/locale -name *.po) ; do
        check_po_file "$i"
        if [ $RATIO -lt 20 ]; then
            git rm -f $i
        fi
    done
}

# Reduce size of po files. This reduces the amount of content imported
# and makes for fewer imports.
# This does not touch the pot files. This way we can reconstruct the po files
# using "msgmerge POTFILE POFILE -o COMPLETEPOFILE".
function compress_po_files {
    local directory=$1

    for i in $(find $directory -name *.po) ; do
        msgattrib --translated --no-location --sort-output "$i" \
            --output="${i}.tmp"
        mv "${i}.tmp" "$i"
    done
}

# Reduce size of po files. This reduces the amount of content imported
# and makes for fewer imports.
# This does not touch the pot files. This way we can reconstruct the po files
# using "msgmerge POTFILE POFILE -o COMPLETEPOFILE".
# Give directory name to not touch files for example under .tox.
# Pass glossary flag to not touch the glossary.
function compress_manual_po_files {
    local directory=$1
    local glossary=$2
    for i in $(find $directory -name *.po) ; do
        if [ "$glossary" -eq "0" ] ; then
            if [[ $i =~ "/glossary/" ]] ; then
                continue
            fi
        fi
        msgattrib --translated --no-location --sort-output "$i" \
            --output="${i}.tmp"
        mv "${i}.tmp" "$i"
    done
}

function pull_from_zanata {

    local project=$1

    # Since Zanata does not currently have an option to not download new
    # files, we download everything, and then remove new files that are not
    # translated enough.
    zanata-cli -B -e pull


    for i in $(find . -name '*.po' ! -path './.*' -prune | cut -b3-); do
        check_po_file "$i"
        # We want new files to be >75% translated. The glossary and
        # common documents in openstack-manuals have that relaxed to
        # >8%.
        percentage=75
        if [ $project = "openstack-manuals" ]; then
            case "$i" in
                *glossary*|*common*)
                    percentage=8
                    ;;
            esac
        fi
        if [ $RATIO -lt $percentage ]; then
            # This means the file is below the ratio, but we only want
            # to delete it, if it is a new file. Files known to git
            # that drop below 20% will be cleaned up by
            # cleanup_po_files.
            if ! git ls-files | grep -xq "$i"; then
                rm -f "$i"
            fi
        fi
    done
}
