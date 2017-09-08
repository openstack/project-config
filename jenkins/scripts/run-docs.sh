#!/bin/bash -xe

# If a bundle file is present, call tox with the jenkins version of
# the test environment so it is used.  Otherwise, use the normal
# (non-bundle) test environment.  Also, run pbr freeze on the
# resulting environment at the end so that we have a record of exactly
# what packages we ended up testing.
#

venv=${1:-venv}
tags_handling=${2:both}

mkdir -p doc/build
export UPPER_CONSTRAINTS_FILE=$(pwd)/upper-constraints.txt
# The "python setup.py build_sphinx" is intentionally executed instead of
# "tox -edocs", because it's the standard python project build interface
# specified in OpenStack Project Testing Interface:
# http://governance.openstack.org/reference/project-testing-interface.html
tox -e$venv -- python setup.py build_sphinx
result=$?

# If the build has not already failed and whereto is installed then
# test the redirects defined in the project.
if [ $result -eq 0 ]; then
    if [ -e .tox/$venv/bin/whereto ]; then
        tox -e $venv -- whereto doc/source/_extra/.htaccess doc/test/redirect-tests.txt
        result=$?
    fi
fi

[ -e .tox/$venv/bin/pbr ] && freezecmd=pbr || freezecmd=pip

echo "Begin pbr freeze output from test virtualenv:"
echo "======================================================================"
.tox/${venv}/bin/${freezecmd} freeze
echo "======================================================================"

MARKER_TEXT="Project: $ZUUL_PROJECT Ref: $ZUUL_REFNAME Build: $ZUUL_UUID Revision: $ZUUL_NEWREV"
echo $MARKER_TEXT > doc/build/html/.root-marker

if [ -z "$ZUUL_REFNAME" ] || [ "$ZUUL_REFNAME" == "master" ] ; then
    : # Leave the docs where they are.
elif echo $ZUUL_REFNAME | grep refs/tags/ >/dev/null ; then
    # Put tagged releases in proper location. All tagged builds get copied to
    # BUILD_DIR/tagname. If this is the latest tagged release the copy of files
    # at BUILD_DIR remains. When Jenkins copies this file the root developer
    # docs are always the latest release with older tags available under the
    # root in the tagname dir.
    TAG=$(echo $ZUUL_REFNAME | sed 's/refs.tags.//')
    if [ ! -z $TAG ] ; then
        # This is a hack to ignore the year.release tags in projects since
        # now all projects use semver based versions instead of date based
        # versions. The date versions will sort higher even though they
        # should not so we just special case it here.
        LATEST=$(git tag | sed -n -e '/^20[0-9]\{2\}\..*$/d' -e '/^[0-9]\+\(\.[0-9]\+\)*$/p' | sort -V | tail -1)
        # Now publish to / and /$TAG if this is the latest version for projects
        # and we are only publishing from the release pipeline,
        # or just /$TAG otherwise.
        if [ "$tags_handling" = "tags-only" -a "$TAG" = "$LATEST" ] ; then
            # Copy the docs into a subdir if this is a tagged build
            mkdir doc/build/$TAG
            cp -R doc/build/html/. doc/build/$TAG
            mv doc/build/$TAG doc/build/html/$TAG
        else
            # Move the docs into a subdir if this is a tagged build
            mv doc/build/html doc/build/tmp
            mkdir doc/build/html
            mv doc/build/tmp doc/build/html/$TAG
        fi
    fi
elif echo $ZUUL_REFNAME | grep stable/ >/dev/null ; then
    # Put stable release changes in dir named after stable release under the
    # build dir. When Jenkins copies these files they will be accessible under
    # the developer docs root using the stable release's name.
    BRANCH=$(echo $ZUUL_REFNAME | sed 's/stable.//')
    if [ ! -z $BRANCH ] ; then
        # Move the docs into a subdir if this is a stable branch build
        mv doc/build/html doc/build/tmp
        mkdir doc/build/html
        mv doc/build/tmp doc/build/html/$BRANCH
    fi
else
    # Put other branch changes in dir named after branch under the
    # build dir. When Jenkins copies these files they will be
    # accessible under the developer docs root using the branch name.
    # EG: feature/foo or milestone-proposed
    BRANCH=$ZUUL_REFNAME
    TOP=`dirname $BRANCH`
    mv doc/build/html doc/build/tmp
    mkdir -p doc/build/html/$TOP
    mv doc/build/tmp doc/build/html/$BRANCH
fi

exit $result
