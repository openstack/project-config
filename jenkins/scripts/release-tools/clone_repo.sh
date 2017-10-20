#!/bin/bash
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
#
# This script is used to clone a repository, possibly starting from a
# local cache, and then update from the global remote. It replaces v2
# of zuul-cloner, and is a bash script instead of being included in
# openstack_releases/gitutils.py because we use it from jobs that
# cannot run pip or tox for security reasons.
#

BINDIR=$(dirname $0)

function print_help {
    cat <<EOF
USAGE:

    clone_repo.sh -h

    clone_repo.sh [--workspace WORK_DIR] [--cache-dir CACHE]
                  [--branch BRANCH] [--ref REF]
                  [--upstream URL] repo-name

Arguments:

  repo-name -- The full repository name, such as
              "openstack/oslo.config". This name is also used as the
              output directory.

Options:

  -h -- Print help.

  --workspace -- The name of the parent directory where the cloned
                 repo should be put.

  --cache-dir -- A location where a local copy of a repo exists and
                 can be used to seed the clone, which will still be
                 updated from the remote. Defaults to $ZUUL_CACHE_DIR
                 or /opt/git.

  --branch -- The branch to check out. Defaults to "master".

  --ref -- The git reference to check out. Defaults to HEAD.

  --upstream -- The upstream server URL, without the git repo
                part. Defaults to git://git.openstack.org

EOF
}

# Defaults
WORKSPACE="."
CACHE_DIR="${ZUUL_CACHE_DIR:-/opt/git}"
BRANCH="master"
REF=""
UPSTREAM="git://git.openstack.org"

OPTS=`getopt -o h --long branch:,cache-dir:,ref:,upstream:,workspace: -n $0 -- "$@"`
if [ $? != 0 ] ; then
    echo "Failed parsing options." >&2
    print_help
    exit 1
fi
eval set -- "$OPTS"
while true; do
    case "$1" in
        -h)
            print_help
            exit 0
            ;;
        --branch)
            BRANCH="$2"
            shift
            shift
            ;;
        --cache-dir)
            CACHE_DIR="$2"
            shift
            shift
            ;;
        --ref)
            REF="$2"
            shift
            shift
            ;;
        --upstream)
            UPSTREAM="$2"
            shift
            shift
            ;;
        --workspace)
            WORKSPACE="$2"
            shift
            shift
            ;;
        --)
            shift
            break
            ;;
    esac
done

REPO="$1"
shift

if [ -z "$REPO" ]; then
    print_help
    echo "ERROR: No repository given."
    exit 1
fi

if [ ! -d "$WORKSPACE" ]; then
    echo "ERROR: Workspace $WORKSPACE does not exist."
    exit 1
fi

set -x
set -e

cache_remote="$CACHE_DIR/$REPO"
if [ ! -d "$cache_remote" ]; then
    echo "WARNING: Cache directory $cache_remote does not exist, ignoring."
    cache_remote=""
fi

upstream_remote="$UPSTREAM/$REPO"
local_dir="$WORKSPACE/$REPO"

# Clone the repository.
if [ -d $local_dir ]; then
    echo "Already have a local copy of $REPO in $local_dir"

elif [ ! -z "$cache_remote" ]; then
    # Clone from the cache then update the origin remote to point
    # upstream so we can pull down more recent changes.
    (cd $WORKSPACE &&
            git clone $cache_remote $REPO &&
            cd $REPO &&
            git remote set-url origin "$upstream_remote"
    )

else
    (cd $WORKSPACE && git clone $upstream_remote $REPO)
fi

# Make sure it is up to date compared to the upstream remote.
(cd $local_dir &&
        git fetch origin --tags
)

if [ ! -z "$REF" ]; then
    # Check out the specified reference.
    (cd $local_dir && git checkout "$REF")
else
    # Check out the expected branch (master is the default, but if the
    # directory already existed we might have checked out something else
    # before so just do it again).
    (cd $local_dir &&
            (git checkout $BRANCH || git checkout master) &&
            git pull --ff-only)
fi
