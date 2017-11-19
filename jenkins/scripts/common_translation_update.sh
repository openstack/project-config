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

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPTSDIR/common.sh

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

    $VENV/bin/python $SCRIPTSDIR/get-modulename.py \
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

# Setup venv with Babel and needed libraries in it.
# Also extract version of project.
function setup_venv {

    # Note that this directory needs to be outside of the source tree,
    # some other functions will fail if it's inside.
    VENV=$(mktemp -d)
    virtualenv $VENV

    # Install babel using global upper constraints.
    $VENV/bin/pip install 'Babel' -c $UPPER_CONSTRAINTS_FILE

    # query-zanata-project-version.py and create-zanata-xml.py need
    # lxml and requests.
    $VENV/bin/pip install 'lxml' -c $UPPER_CONSTRAINTS_FILE
    $VENV/bin/pip install 'requests' -c $UPPER_CONSTRAINTS_FILE

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

# Setup nodejs within the python venv. Match the nodejs version with
# the one used in the nodejs6-npm jobs.
function setup_nodeenv {

    $VENV/bin/pip install -U nodeenv
    NODE_VENV=$VENV/node_venv
    $VENV/bin/nodeenv --node 6.9.4 $NODE_VENV
    source $NODE_VENV/bin/activate

}

# Setup a project for Zanata. This is used by both Python and Django projects.
# syntax: setup_project <project> <zanata_version> <modulename> [<modulename> ...]
function setup_project {
    local project=$1
    local version=$2
    shift 2
    # All argument(s) contain module names now.

    # Exclude all dot-files, particuarly for things such such as .tox
    # and .venv
    local exclude='.*/**'

    $VENV/bin/python $SCRIPTSDIR/create-zanata-xml.py \
        -p $project -v $version --srcdir . --txdir . \
        -r '**/*.pot' '{path}/{locale_with_underscore}/LC_MESSAGES/{filename}.po' \
        -e "$exclude" -f zanata.xml
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

    $VENV/bin/python $SCRIPTSDIR/create-zanata-xml.py \
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

    $VENV/bin/python $SCRIPTSDIR/create-zanata-xml.py \
        -p $project -v $version \
        --srcdir doc/upstream-training/source/locale \
        --txdir doc/upstream-training/source/locale \
        -f zanata.xml
}

# Setup a i18n project for Zanata
function setup_i18n {
    local project=i18n
    local version=${1:-master}

    # Update the .pot file
    tox -e generatepot

    $VENV/bin/python $SCRIPTSDIR/create-zanata-xml.py \
        -p $project -v $version \
        --srcdir doc/source/locale \
        --txdir doc/source/locale \
        -f zanata.xml
}

# Setup a ReactJS project for Zanata
function setup_reactjs_project {
    local project=$1
    local version=$2

    local exclude='node_modules/**'

    setup_nodeenv

    # Extract messages
    npm install
    npm run build
    # Transform them into .pot files
    npm run json2pot

    $VENV/bin/python $SCRIPTSDIR/create-zanata-xml.py \
        -p $project -v $version --srcdir . --txdir . \
        -r '**/*.pot' '{path}/{locale}.po' \
        -e "$exclude" -f zanata.xml
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
https://docs.openstack.org/i18n/latest/reviewing-translation-import.html
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
        CUR_PATCH_ID=$(git show | git patch-id | awk '{print $1}')
        # Don't submit if we have the same patch id of previously submitted
        # patchset
        if [[ "${PREV_PATCH_ID}" != "${CUR_PATCH_ID}" ]]; then
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
    fi
    return $success
}


# Delete empty pot files
function check_empty_pot {
    local pot=$1

    # We don't need to add or send around empty source files.
    trans=$(msgfmt --statistics -o /dev/null ${pot} 2>&1)
    if [ "$trans" = "0 translated messages." ] ; then
        rm $pot
        # Remove file from git if it's under version control. We previously
        # had all pot files under version control, so remove file also
        # from git if needed.
        git rm --ignore-unmatch $pot
    fi
}

# Run extract_messages for python projects.
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
        https://git.openstack.org/openstack/horizon.git $HORIZON_ROOT/horizon
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
    local keep_workdir=$1

    # Extract messages
    .venv/bin/sphinx-build -b gettext -d releasenotes/build/doctrees \
        releasenotes/source releasenotes/work
    rm -rf releasenotes/build
    # Concatenate messages into one POT file
    mkdir -p releasenotes/source/locale/
    msgcat --sort-by-file releasenotes/work/*.pot \
        > releasenotes/source/locale/releasenotes.pot
    if [ ! -n "$keep_workdir" ]; then
        rm -rf releasenotes/work
    fi
}

# Check releasenote translation progress per language.
# It checks the progress per release. Add the release note translation
# if at least one release is well translated (>= 75%).
# Keep the release note translation in the git repository
# if at least one release is translated >= 40%.
# Otherwise (< 40%) the translation are removed.
#
# NOTE: this function assume POT files in releasenotes/work
# extracted by extract_messages_releasenotes().
# The workdir should be clean up by the caller.
function check_releasenotes_per_language {
    local lang_po=$1

    # The expected PO location is
    # releasenotes/source/locale/<lang>/LC_MESSAGES/releasenotes.po.
    # Extract language name from 4th component.
    local lang
    lang=$(echo $lang_po | cut -d / -f 4)

    local release_pot
    local release_name
    local workdir=releasenotes/work

    local has_high_thresh=0
    local has_low_thresh=0

    mkdir -p $workdir/$lang
    for release_pot in $(find $workdir -name '*.pot'); do
        release_name=$(basename $release_pot .pot)
        # The index file usually contains small number of words,
        # so we skip to check it.
        if [ $release_name = "index" ]; then
            continue
        fi
        msgmerge --quiet -o $workdir/$lang/$release_name.po $lang_po $release_pot
        check_po_file $workdir/$lang/$release_name.po
        if [ $RATIO -ge 75 ]; then
            has_high_thresh=1
            has_low_thresh=1
        fi
        if [ $RATIO -ge 40 ]; then
            has_low_thresh=1
        fi
    done

    if ! git ls-files | grep -xq $lang_po; then
        if [ $has_high_thresh -eq 0 ]; then
            rm -f $lang_po
        fi
    else
        if [ $has_low_thresh -eq 0 ]; then
            git rm -f --ignore-unmatch $lang_po
        fi
    fi
}

# Filter out files that we do not want to commit.
# Sets global variable INVALID_PO_FILE to 1 if any invalid files are
# found.
function filter_commits {
    local ret

    # Don't add new empty files.
    for f in $(git diff --cached --name-only --diff-filter=A); do
        case "$f" in
            *.po)
                # Files should have at least one non-empty msgid string.
                if ! grep -q 'msgid "[^"]' "$f" ; then
                    git reset -q "$f"
                    rm "$f"
                fi
                ;;
            *.json)
                # JSON files fail msgid test. Ignore the locale key and confirm
                # there are string keys in the messages dictionary itself.
                if ! grep -q '"[^"].*":\s*"' "$f" ; then
                    git reset -q "$f"
                    rm "$f"
                fi
                ;;
            *)
                # Anything else is not a translation file, remove it.
                git reset -q "$f"
                rm "$f"
                ;;
        esac
    done

    # Don't send files where the only things which have changed are
    # the creation date, the version number, the revision date,
    # name of last translator, comment lines, or diff file information.
    REAL_CHANGE=0
    # Always remove obsolete log level translations.
    for f in $(git diff --cached --name-only --diff-filter=D); do
        if [[ $f =~ -log-(critical|error|info|warning).po$ ]] ; then
            REAL_CHANGE=1
        fi
    done
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

# Remove obsolete log lovel files. We  have added them in the past but
# do not translate them anymore, so let's eventually remove them.
function cleanup_log_files {
    local modulename=$1
    local levels="info warning error critical"

    for i in $(find $modulename -name *.po) ; do
        # We do not store the log level files anymore, remove them
        # from git.
        local bi=$(basename $i)

        for level in $levels ; do
            if [[ "$bi" == "$modulename-log-$level.po" ]] ; then
                git rm -f --ignore-unmatch $i
            fi
        done
    done
}


# Remove all pot files, we publish them to
# http://tarballs.openstack.org/translation-source/{name}/VERSION ,
# let's not store them in git at all.
# Previously, we had those files in git, remove them now if there
# are still there.
function cleanup_pot_files {
    local modulename=$1

    for i in $(find $modulename -name *.pot) ; do
        # Remove file; both local and from git if needed.
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

    # We skip directories starting with '.' because they never contain
    # translations for the project (in particular, '.tox'). Likewise
    # 'node_modules' only contains dependencies and should be ignored.
    for i in $(find . -name '*.po' ! -path './.*' ! -path './node_modules/*' -prune | cut -b3-); do
        # We check release note translation percentage per release.
        # To check this we need to extract messages per RST file.
        # Let's defer checking it to propose_releasenotes.
        local basefn=
        if [ "$(basename $i)" = "releasenotes.po" ]; then
            continue
        fi
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
    local target=.translation-source/$ZANATA_VERSION/

    for m in $all_modules ; do
        for f in `find $m -name "*.pot" ` ; do
            local fd=$(dirname $f)
            mkdir -p $target/$fd
            cp $f $target/$f
        done
    done
}
