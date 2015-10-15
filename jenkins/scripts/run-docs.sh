#!/bin/bash -xe

# If a bundle file is present, call tox with the jenkins version of
# the test environment so it is used.  Otherwise, use the normal
# (non-bundle) test environment.  Also, run pbr freeze on the
# resulting environment at the end so that we have a record of exactly
# what packages we ended up testing.
#

venv=${1:-venv}

mkdir -p doc/build
export HUDSON_PUBLISH_DOCS=1
export UPPER_CONSTRAINTS_FILE=$(pwd)/upper-constraints.txt
# The "python setup.py build_sphinx" is intentionally executed instead of
# "tox -edocs", because it's the standard python project build interface
# specified in OpenStack Project Testing Interface:
# http://governance.openstack.org/reference/project-testing-interface.html
tox -e$venv -- python setup.py build_sphinx
result=$?

[ -e .tox/$venv/bin/pbr ] && freezecmd=pbr || freezecmd=pip

echo "Begin pbr freeze output from test virtualenv:"
echo "======================================================================"
.tox/${venv}/bin/${freezecmd} freeze
echo "======================================================================"

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
        LATEST=$(git tag | sed -n -e '/^20[0-9]\{2\}\..*$/d' -e '/^\([0-9]\+\.\?\)\{1,3\}.*$/p' | sort -V | tail -1)
        # Now publish to / and /$TAG if this is the latest version or
        # just /$TAG if this is not the latest version.
        if [ "$TAG" = "$LATEST" ] ; then
            # Copy the docs into a subdir if this is a tagged build
            mkdir doc/build/$TAG
            cp -R doc/build/html/* doc/build/$TAG
            mv doc/build/$TAG doc/build/html/$TAG
        else
            # Move the docs into a subdir if this is a tagged build
            mkdir doc/build/$TAG
            mv doc/build/html/* doc/build/$TAG
            mv doc/build/$TAG doc/build/html/$TAG
        fi
    fi
elif echo $ZUUL_REFNAME | grep stable/ >/dev/null ; then
    # Put stable release changes in dir named after stable release under the
    # build dir. When Jenkins copies these files they will be accessible under
    # the developer docs root using the stable release's name.
    BRANCH=$(echo $ZUUL_REFNAME | sed 's/stable.//')
    if [ ! -z $BRANCH ] ; then
        # Move the docs into a subdir if this is a stable branch build
        mkdir doc/build/$BRANCH
        mv doc/build/html/* doc/build/$BRANCH
        mv doc/build/$BRANCH doc/build/html/$BRANCH
    fi
else
    # Put other branch changes in dir named after branch under the
    # build dir. When Jenkins copies these files they will be
    # accessible under the developer docs root using the branch name.
    # EG: feature/foo or milestone-proposed
    BRANCH=$ZUUL_REFNAME
    mkdir doc/build/tmp
    mv doc/build/html/* doc/build/tmp
    mkdir -p doc/build/html/$BRANCH
    mv doc/build/tmp/* doc/build/html/$BRANCH
fi

exit $result
