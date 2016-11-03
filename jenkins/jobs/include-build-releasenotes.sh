#!/bin/bash -xe

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

DOCNAME=releasenotes
DIRECTORY=releasenotes

script_path=/usr/local/jenkins/slave_scripts

# Mapping of language codes to language names
declare -A LANG_NAME=(
    ["de"]="German"
    ["en_AU"]="English (Australian)"
    ["en_GB"]="English (United Kingdom)"
    ["es"]="Spanish"
    ["fr"]="French"
    ["id"]="Indonesian"
    ["it"]="Italian"
    ["ja"]="Japanese"
    ["ko_KR"]="Korean (South Korea)"
    ["pt_BR"]="Portuguese (Brazil)"
    ["ru"]="Russian"
    ["tr_TR"]="Turkish (Turkey)"
    ["zh_CN"]="Chinese (China)"
)

# This file always exists in OpenStack CI jobs, check for it so that
# it can be used manually as well.
if [ -e "$(pwd)/upper-constraints.txt" ]; then
    export UPPER_CONSTRAINTS_FILE=$(pwd)/upper-constraints.txt
fi

if [ ! -e ${DIRECTORY}/source/locale/ ]; then
    echo "No translations found, only building normal release notes"
    $script_path/run-tox.sh releasenotes
    exit 0
fi

# Check that locale_dirs is really set, otherwise translations
# will not work.
if ! grep -q -E '^locale_dirs *=' $DIRECTORY/source/conf.py; then
    echo "Translations exist and locale_dirs missing in source/conf.py"
    exit 1
fi


REFERENCES=`mktemp`
trap "rm -f -- '$REFERENCES'" EXIT

# Extract translations
tox -e venv -- sphinx-build -b gettext \
    -d ${DIRECTORY}/build/doctrees.gettext \
    ${DIRECTORY}/source/ \
    ${DIRECTORY}/source/locale/

# Add links for translations to index file
cat <<EOF >> ${REFERENCES}

Translated Release Notes
========================

EOF

# Check all language translation resources
for locale in `find ${DIRECTORY}/source/locale/ -maxdepth 1 -type d` ; do
    # Skip if it is not a valid language translation resource.
    if [ ! -e ${locale}/LC_MESSAGES/${DOCNAME}.po ]; then
        continue
    fi
    language=$(basename $locale)

    echo "Building $language translation"

    # Prepare all translation resources
    for pot in ${DIRECTORY}/source/locale/*.pot ; do
        # Get filename
        resname=$(basename ${pot} .pot)

        # Merge all translation resources. Note this is done the same
        # way as done in common_translation_update.sh where we merge
        # all strings together in a single file.
        msgmerge --silent -o \
            ${DIRECTORY}/source/locale/${language}/LC_MESSAGES/${resname}.po \
            ${DIRECTORY}/source/locale/${language}/LC_MESSAGES/${DOCNAME}.po \
            ${pot}
        # Compile all translation resources
        msgfmt -o \
            ${DIRECTORY}/source/locale/${language}/LC_MESSAGES/${resname}.mo \
            ${DIRECTORY}/source/locale/${language}/LC_MESSAGES/${resname}.po
    done

    # Build translated document
    tox -e venv -- sphinx-build -b html -D language=${language} \
        -d "${DIRECTORY}/build/doctrees.${language}" \
        ${DIRECTORY}/source/ ${DIRECTORY}/build/html/${language}

    # Reference translated document from index file
    if [ ${LANG_NAME["${language}"]+_} ] ; then
        name=${LANG_NAME["${language}"]}
        name+=" (${language})"
        echo "* \`$name <${language}/index.html>\`__" >> ${REFERENCES}
    else
        echo "* \`${language} <${language}/index.html>\`__" >> ${REFERENCES}
    fi

    # Remove newly created files
    git clean -f -q ${DIRECTORY}/source/locale/${language}/LC_MESSAGES/*.po
    git clean -f -x -q ${DIRECTORY}/source/locale/${language}/LC_MESSAGES/*.mo
    # revert changes to po file
    git reset -q ${DIRECTORY}/source/locale/${language}/LC_MESSAGES/${DOCNAME}.po
    git checkout -- ${DIRECTORY}/source/locale/${language}/LC_MESSAGES/${DOCNAME}.po
done

# Now append our references to the index file. We cannot do this
# earlier since the sphinx commands will read this file.
cat ${REFERENCES} >> ${DIRECTORY}/source/index.rst

# Remove newly created pot files
rm -f ${DIRECTORY}/source/locale/*.pot

# Now build releasenotes with reference to translations
$script_path/run-tox.sh releasenotes

# Revert any changes to the index file.
git checkout -- ${DIRECTORY}/source/index.rst
