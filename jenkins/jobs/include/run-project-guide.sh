#!/bin/bash -xe

# This script is used to publish project-specific deploy-guide and
# install-guide documents to the proper place. Master will be
# published to a draft directory, stable/X will be published to the X
# directory. For example stable/newton documents will life in the
# newton directory.

# You need to pass in the following variables:
# VENV - virtual env to use
# GUIDEDIR - directory for building

if [ -z "$VENV" ] ; then
    echo "The variable VENV is not set."
    exit 1
fi
if [ -z "$GUIDEDIR" ] ; then
    echo "The variable GUIDEDIR is not set."
    exit 1
fi

export UPPER_CONSTRAINTS_FILE=$(pwd)/upper-constraints.txt

tox -e $VENV

[ -e .tox/$VENV/bin/pbr ] && freezecmd=pbr || freezecmd=pip

echo "Begin pbr freeze output from test virtualenv:"
echo "======================================================================"
.tox/${VENV}/bin/${freezecmd} freeze
echo "======================================================================"

MARKER_TEXT="Project: $ZUUL_PROJECT Ref: $ZUUL_REFNAME Build: $ZUUL_UUID Revision: $ZUUL_NEWREV"
echo $MARKER_TEXT > $GUIDEDIR/build/html/.root-marker

if [ -z "$ZUUL_REFNAME" ]; then
    TARGET=""
    # Leave documents where they are
elif [ "$ZUUL_REFNAME" == "master" ] ; then
    TARGET=draft
elif echo $ZUUL_REFNAME | grep stable/ >/dev/null ; then
    # Put stable release changes in dir named after stable release under the
    # build dir. When Jenkins copies these files they will be accessible under
    # the developer docs root using the name of the stable release.
    TARGET=$(echo $ZUUL_REFNAME | sed 's/stable.//')
else
    # Put other branch changes in dir named after branch under the
    # build dir. When Jenkins copies these files they will be
    # accessible under the developer docs root using the branch name.
    # EG: feature/foo or milestone-proposed
    TARGET=$ZUUL_REFNAME
fi

if [ ! -z $TARGET ] ; then
    # Move the docs into subdir based on branch
    TOP=`dirname $TARGET`
    mv $GUIDEDIR/build/html $GUIDEDIR/build/tmp
    mkdir -p $GUIDEDIR/build/html/$TOP
    mv $GUIDEDIR/build/tmp $GUIDEDIR/build/html/$TARGET
fi

exit
