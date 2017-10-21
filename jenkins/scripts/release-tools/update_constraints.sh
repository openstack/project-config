#!/bin/bash
#
# Script to update the constraints file in the requirements repo when
# a release is tagged.
#
# All Rights Reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

set -x

TOOLSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $TOOLSDIR/functions

function usage {
    echo "Usage: update_constraints.sh version"
    echo
    echo "Example: update_constraints.sh 3.0.3"
}

if [ $# -lt 1 ]; then
    usage
    exit 2
fi

VERSION=$1

# Extract the tag message by parsing the git show output, which looks
# something like:
#
# tag 2.0.0
# Tagger: Doug Hellmann <doug@doughellmann.com>
# Date:   Tue Dec 1 21:45:44 2015 +0000
#
# python-keystoneclient 2.0.0 release
#
# meta:version: 2.0.0
# meta:series: mitaka
# meta:release-type: release
# -----BEGIN PGP SIGNATURE-----
# Comment: GPGTools - http://gpgtools.org
#
# iQEcBAABAgAGBQJWXhUIAAoJEDttBqDEKEN62rMH/ihLAGfw5GxPLmdEpt7gsLJu
# ...
#
TAG_META=$(git show --no-patch "$VERSION" | grep '^meta:' || true)
if [[ -z "$TAG_META" ]]; then
    echo "WARNING: Missing meta lines in $VERSION tag message,"
    echo "         skipping announcement."
    echo
    echo "Was the tag for $VERSION created with release.sh?"
    exit 0
fi

function get_tag_meta {
    typeset fieldname="$1"

    echo "$TAG_META" | grep "^meta:$fieldname:" | cut -f2 -d' '
}

# Find the series information from the tag metadata in the comment.
SERIES=$(get_tag_meta series)

# Pick up the repository name from the git URL.
SHORTNAME=$(basename $(git config --local remote.origin.url))

# Apply the PEP 503 rules to turn the dist name into a canonical form,
# in case that's the version that appears in upper-constraints.txt. We
# have to try substituting both versions because we have a mix in that
# file and if we rename projects we'll end up with bad references to
# existing build artifacts.
function pep503 {
    echo $1 | sed -e 's/[-_.]\+/-/g' | tr '[:upper:]' '[:lower:]'
}

# Try to propose a constraints update.
#
# NOTE(dhellmann): If the setup_requires dependencies are not
# installed yet, running setuptools commands will install
# them. Capturing the output of a setuptools command that includes
# the output from installing packages produces a bad dist_name, so
# we first ask for the name without saving the output and then we
# ask for it again and save the output to get a clean
# version. This is why we can't have nice things.
python setup.py --name
dist_name=$(python setup.py --name)
canonical_name=$(pep503 $dist_name)
if [[ -z "$dist_name" ]]; then
    echo "Could not determine the name of the constraint to update"
else
    setup_temp_space update-constraints-$SHORTNAME
    # NOTE(dhellmann): clone_repo defaults to checking out master if
    # the named branch doesn't exist.
    clone_repo openstack/requirements stable/$SERIES
    cd openstack/requirements
    git checkout -b "$dist_name-$VERSION"
    sed -e "s/^${dist_name}=.*/$dist_name===$VERSION/" --in-place upper-constraints.txt
    sed -e "s/^${canonical_name}=.*/$canonical_name===$VERSION/" --in-place upper-constraints.txt
    if git commit -a -m "update constraint for $dist_name to new release $VERSION

$TAG_META
"; then
        git show
        git review -t 'new-release'
    else
        echo "Skipping git review because there are no updates."
    fi
fi

exit 0
