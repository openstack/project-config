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

# Set start of timestamp for subunit
TRANS_START_TIME=$(date +%s)
SUBUNIT_OUTPUT=testrepository.subunit

# Topic to use for our changes
TOPIC=zanata/translations

# Used for setup.py babel commands
QUIET="--quiet"

# Have invalid files been found?
INVALID_PO_FILE=0

# ERROR_ABORT signals whether the script aborts with failure, will be
# set to 0 on successful run.
ERROR_ABORT=1

# We need a UTF-8 locale, set it properly in case it's not set.
export LANG=en_US.UTF-8

trap "finish" EXIT

# Set up some branch dependent variables
function init_branch {
    local branch=$1

    # The calling environment puts upper-constraints.txt in our
    # working directory.
    # UPPER_CONSTRAINTS_FILE needs to be exported so that tox can use it
    # if needed.
    export UPPER_CONSTRAINTS_FILE=$(pwd)/upper-constraints.txt
    GIT_BRANCH=$branch
}


# Get a module name of a project
function get_modulename {
    local project=$1
    local target=$2

    /usr/local/jenkins/slave_scripts/get-modulename.py \
        -p $project -t $target
}

function finish {

    # Only run this if VENV is setup.
    if [ "$VENV" != "" ] ; then
        if [[ "$ERROR_ABORT" -eq 1 ]] ; then
            $VENV/bin/generate-subunit $TRANS_START_TIME $SECONDS \
                'fail' $JOBNAME >> $SUBUNIT_OUTPUT

        else
            $VENV/bin/generate-subunit $TRANS_START_TIME $SECONDS \
                'success' $JOBNAME >> $SUBUNIT_OUTPUT
        fi

        gzip -9 $SUBUNIT_OUTPUT

        # Delete temporary directories
        rm -rf $VENV
        VENV=""
    fi
    if [ "$HORIZON_ROOT" != "" ] ; then
        rm -rf $HORIZON_ROOT
        HORIZON_ROOT=""
    fi
}

# Setup venv with Babel in it.
# Also extract version of project.
function setup_venv {

    # Note that this directory needs to be outside of the source tree,
    # some other functions will fail if it's inside.
    VENV=$(mktemp -d)
    virtualenv $VENV

    # Install babel using global upper constraints.
    $VENV/bin/pip install 'Babel' -c $UPPER_CONSTRAINTS_FILE

    # Get version, run this twice - the first one will install pbr
    # and get extra output.
    # Note this might fail in some projects if the setup hook includes
    # additional hooks like in tacker repository. Use
    set +e
    $VENV/bin/python setup.py --version
    VERSION=$($VENV/bin/python setup.py --version)
    set -e
    VERSION=${VERSION:-unknown}

    # Install subunit for the subunit output stream for
    # healthcheck.openstack.org.
    $VENV/bin/pip install -U os-testr
}

# Setup a project for Zanata. This is used by both Python and Django projects.
# syntax: setup_project <project> <zanata_version> <modulename> [<modulename> ...]
function setup_project {
    local project=$1
    local version=$2
    shift 2
    # All argument(s) contain module names now.

    local exclude='.tox/**'

    # For projects with one module on stable/mitaka, we use "old" setup.
    # Note that stable/mitaka is only stable translated branch for
    # projects.
    # TODO(jaegerandi): Remove once mitaka translation ends.
    if [ $# -eq 1 ] && [ "$version" == "stable-mitaka" ] ; then
        local modulename=$1
        /usr/local/jenkins/slave_scripts/create-zanata-xml.py \
            -p $project -v $version --srcdir $modulename/locale \
            --txdir $modulename/locale \
            -r '**/*.pot' '{locale_with_underscore}/LC_MESSAGES/{filename}.po' \
            -f zanata.xml
    else
        /usr/local/jenkins/slave_scripts/create-zanata-xml.py \
            -p $project -v $version --srcdir . --txdir . \
            -r '**/*.pot' '{path}/{locale_with_underscore}/LC_MESSAGES/{filename}.po' \
            -e "$exclude" -f zanata.xml
    fi
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
# security-guide) for Zanata
function setup_manuals {
    local project=$1
    local version=${2:-master}

    # Fill in associative array SPECIAL_BOOKS
    declare -A SPECIAL_BOOKS
    source doc-tools-check-languages.conf

    # Grab all of the rules for the documents we care about
    ZANATA_RULES=

    # List of directories to skip.

    # All manuals have a source/common subdirectory that is a symlink
    # to doc/common in openstack-manuals. We have to exclude this
    # source/common directory everywhere, only doc/common gets
    # translated.
    EXCLUDE='.*/**,**/source/common/**'

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
        IS_RST=0
        if [ ${SPECIAL_BOOKS["${DOCNAME}"]+_} ] ; then
            case "${SPECIAL_BOOKS["${DOCNAME}"]}" in
                RST)
                    IS_RST=1
                    ;;
                skip)
                    EXCLUDE="$EXCLUDE,${DocFolder}/${DOCNAME}/**"
                    continue
                    ;;
            esac
        fi
        if [ ${IS_RST} -eq 1 ] ; then
            tox -e generatepot-rst -- ${DOCNAME}
            ZANATA_RULES="$ZANATA_RULES -r ${ZanataDocFolder}/${DOCNAME}/source/locale/${DOCNAME}.pot ${DocFolder}/${DOCNAME}/source/locale/{locale_with_underscore}/LC_MESSAGES/${DOCNAME}.po"
        else
            # Update the .pot file
            ./tools/generatepot ${DOCNAME}
            if [ -f ${DocFolder}/${DOCNAME}/locale/${DOCNAME}.pot ]; then
                ZANATA_RULES="$ZANATA_RULES -r ${ZanataDocFolder}/${DOCNAME}/locale/${DOCNAME}.pot ${DocFolder}/${DOCNAME}/locale/{locale_with_underscore}.po"
            fi
        fi
    done

    # Project setup and updating POT files for release notes.
    if [[ $project == "openstack-manuals" ]] && [[ $version == "master" ]]; then
        ZANATA_RULES="$ZANATA_RULES -r ./releasenotes/source/locale/releasenotes.pot releasenotes/source/locale/{locale_with_underscore}/LC_MESSAGES/releasenotes.po"
    fi

    /usr/local/jenkins/slave_scripts/create-zanata-xml.py \
        -p $project -v $version --srcdir . --txdir . \
        $ZANATA_RULES -e "$EXCLUDE" \
        -f zanata.xml
}

# Setup a training-guides project for Zanata
function setup_training_guides {
    local project=training-guides
    local version=${1:-master}

    # Update the .pot file
    tox -e generatepot-training

    /usr/local/jenkins/slave_scripts/create-zanata-xml.py \
        -p $project -v $version \
        --srcdir doc/upstream-training/source/locale \
        --txdir doc/upstream-training/source/locale \
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
    read -d '' INITIAL_COMMIT_MSG <<EOF
Imported Translations from Zanata

For more information about this automatic import see:
https://wiki.openstack.org/wiki/Translations/Infrastructure
EOF
    set -e
    git review -s

    # See if there is an open change in the zanata/translations
    # topic. If so, get the change id for the existing change for use
    # in the commit msg.
    # Function setup_commit_message will set CHANGE_ID if a change
    # exists and will always set COMMIT_MSG.
    setup_commit_message $FULL_PROJECT proposal-bot $branch $TOPIC "$INITIAL_COMMIT_MSG"

    # Function check_already_approved will quit the proposal process if there
    # is already an approved job with the same CHANGE_ID
    check_already_approved $CHANGE_ID
}

# Propose patch using COMMIT_MSG
function send_patch {
    local branch=${1:-master}
    local output
    local ret
    local success=0

    # We don't have any repos storing zanata.xml, so just remove it.
    rm -f zanata.xml

    # Don't send a review if nothing has changed.
    if [ $(git diff --cached | wc -l) -gt 0 ]; then
        # Commit and review
        git commit -F- <<EOF
$COMMIT_MSG
EOF
        # Do error checking manually to ignore one class of failure.
        set +e
        # We cannot rely on the default branch in .gitreview being
        # correct so we are very explicit here.
        output=$(git review -t $TOPIC $branch)
        ret=$?
        [[ "$ret" -eq 0 || "$output" =~ "No changes between prior commit" ]]
        success=$?
        set -e
    fi
    return $success
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

# Delete empty pot files
function check_empty_pot {
    local pot=$1

    # We don't need to add or send around empty source files.
    trans=$(msgfmt --statistics -o /dev/null ${pot} 2>&1)
    if [ "$trans" = "0 translated messages." ] ; then
        rm $pot
        # Remove file from git if it's under version control.
        git rm --ignore-unmatch $pot
    fi
}

# Run extract_messages for python projects.
# Needs variables setup via setup_loglevel_vars.
function extract_messages_python {
    local modulename=$1

    local pot=${modulename}/locale/${modulename}.pot

    # In case this is an initial run, the locale directory might not
    # exist, so create it since extract_messages will fail if it does
    # not exist. So, create it if needed.
    mkdir -p ${modulename}/locale

    # Update the .pot files
    # The "_C" and "_P" prefix are for more-gettext-support blueprint,
    # "_C" for message with context, "_P" for plural form message.
    $VENV/bin/pybabel ${QUIET} extract \
        --add-comments Translators: \
        --msgid-bugs-address="https://bugs.launchpad.net/openstack-i18n/" \
        --project=${PROJECT} --version=${VERSION} \
        -k "_C:1c,2" -k "_P:1,2" \
        -o ${pot} ${modulename}
    check_empty_pot ${pot}

    # Update the log level .pot files
    for level in $LEVELS ; do
        pot=${modulename}/locale/${modulename}-log-${level}.pot
        $VENV/bin/pybabel ${QUIET} extract --no-default-keywords \
            --add-comments Translators: \
            --msgid-bugs-address="https://bugs.launchpad.net/openstack-i18n/" \
            --project=${PROJECT} --version=${VERSION} \
            -k ${LKEYWORD[$level]} \
            -o ${pot} ${modulename}
        check_empty_pot ${pot}
    done
}

# Django projects need horizon installed for extraction, install it in
# our venv. The function setup_venv needs to be called first.
function install_horizon {

    # TODO(jaegerandi): Switch to zuul-cloner once it's safe to use
    # zuul-cloner in post jobs and we have a persistent cache on
    # proposal node.
    HORIZON_ROOT=$(mktemp -d)

    # Checkout same branch of horizon as the project - including
    # same constraints.
    git clone --depth=1 --branch $GIT_BRANCH \
        git://git.openstack.org/openstack/horizon.git $HORIZON_ROOT/horizon
    (cd ${HORIZON_ROOT}/horizon && $VENV/bin/pip install -c $UPPER_CONSTRAINTS_FILE .)
    rm -rf HORIZON_ROOT
    HORIZON_ROOT=""
}


# Extract messages for a django project, we need to update django.pot
# and djangojs.pot.
function extract_messages_django {
    local modulename=$1
    local pot

    KEYWORDS="-k gettext_noop -k gettext_lazy -k ngettext_lazy:1,2"
    KEYWORDS+=" -k ugettext_noop -k ugettext_lazy -k ungettext_lazy:1,2"
    KEYWORDS+=" -k npgettext:1c,2,3 -k pgettext_lazy:1c,2 -k npgettext_lazy:1c,2,3"

    for DOMAIN in djangojs django ; do
        if [ -f babel-${DOMAIN}.cfg ]; then
            mkdir -p ${modulename}/locale
            pot=${modulename}/locale/${DOMAIN}.pot
            touch ${pot}
            $VENV/bin/pybabel ${QUIET} extract -F babel-${DOMAIN}.cfg \
                --add-comments Translators: \
                --msgid-bugs-address="https://bugs.launchpad.net/openstack-i18n/" \
                --project=${PROJECT} --version=${VERSION} \
                $KEYWORDS \
                -o ${pot} ${modulename}
            check_empty_pot ${pot}
        fi
    done
}

# Extract releasenotes messages
function extract_messages_releasenotes {
    # Extract messages
    tox -e venv -- sphinx-build -b gettext -d releasenotes/build/doctrees \
        releasenotes/source releasenotes/work
    rm -rf releasenotes/build
    # Concatenate messages into one POT file
    mkdir -p releasenotes/source/locale/
    msgcat --sort-by-file releasenotes/work/*.pot \
        > releasenotes/source/locale/releasenotes.pot
    rm -rf releasenotes/work
}

# Filter out files that we do not want to commit.
# Sets global variable INVALID_PO_FILE to 1 if any invalid files are
# found.
function filter_commits {
    local ret

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
    REAL_CHANGE=0
    # Don't iterate over deleted files
    for f in $(git diff --cached --name-only --diff-filter=AM); do
        # It's ok if the grep fails
        set +e
        REGEX="(POT-Creation-Date|Project-Id-Version|PO-Revision-Date|Last-Translator|X-Generator|Generated-By)"
        changed=$(git diff --cached "$f" \
            | egrep -v "$REGEX" \
            | egrep -c "^([-+][^-+#])")
        added=$(git diff --cached "$f" \
            | egrep -v "$REGEX" \
            | egrep -c "^([+][^+#])")
        set -e
        # Check that imported po files are valid
        if [[ $f =~ .po$ ]] ; then
            set +e
            msgfmt --check-format -o /dev/null $f
            ret=$?
            set -e
            if [ $ret -ne 0 ] ; then
                # Set change to zero so that next expression reverts
                # change of this file.
                changed=0
                echo "ERROR: File $f is an invalid po file."
                echo "ERROR: The file has not been imported and needs fixing!"
                INVALID_PO_FILE=1
            fi
        fi
        if [ $changed -eq 0 ]; then
            git reset -q "$f"
            git checkout -- "$f"
        # We will take this import if at least one change adds new content,
        # thus adding a new translation.
        # If only lines are removed, we do not need to generate an import.
        elif [ $added -gt 0 ] ; then
            REAL_CHANGE=1
        fi
    done

    # If no file has any real change, revert all changes.
    if [ $REAL_CHANGE -eq 0 ] ; then
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
    local modulename=$1

    for i in $(find $modulename -name *.po) ; do
        check_po_file "$i"
        if [ $RATIO -lt 40 ]; then
            git rm -f --ignore-unmatch $i
        fi
    done
}


# Remove all pot files, we publish them to
# http://tarballs.openstack.org/translation-source/{name}/VERSION ,
# let's not store them in git at all.
function cleanup_pot_files {
    local modulename=$1

    for i in $(find $modulename -name *.pot) ; do
        # Remove file, it might be a new file unknown to git.
        rm $i
        git rm -f --ignore-unmatch $i
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

function pull_from_zanata {

    local project=$1

    # Since Zanata does not currently have an option to not download new
    # files, we download everything, and then remove new files that are not
    # translated enough.
    zanata-cli -B -e pull

    for i in $(find . -name '*.po' ! -path './.*' -prune | cut -b3-); do
        check_po_file "$i"
        # We want new files to be >75% translated. The
        # common documents in openstack-manuals have that relaxed to
        # >40%.
        percentage=75
        if [ $project = "openstack-manuals" ]; then
            case "$i" in
                *common*)
                    percentage=40
                    ;;
            esac
        fi
        if [ $RATIO -lt $percentage ]; then
            # This means the file is below the ratio, but we only want
            # to delete it, if it is a new file. Files known to git
            # that drop below 40% will be cleaned up by
            # cleanup_po_files.
            if ! git ls-files | grep -xq "$i"; then
                rm -f "$i"
            fi
        fi
    done
}

# Copy all pot files in modulename directory to temporary path for
# publishing. This uses the exact same path.
function copy_pot {
    local all_modules=$1
    local target=.translation-source/$PROJECT/$ZANATA_VERSION/

    for m in $all_modules ; do
        for f in `find $m -name "*.pot" ` ; do
            local fd=$(dirname $f)
            mkdir -p $target/$fd
            cp $f $target/$f
        done
    done
}
