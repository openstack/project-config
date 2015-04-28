#!/bin/bash -e

GERRIT_SITE=$1
GIT_ORIGIN=$2

# git can sometimes get itself infinitely stuck with transient network
# errors or other issues with the remote end.  This wraps git in a
# timeout/retry loop and is intended to watch over non-local git
# processes that might hang.  GIT_TIMEOUT, if set, is passed directly
# to timeout(1); otherwise the default value of 0 maintains the status
# quo of waiting forever.
# usage: git_timed <git-command>
function git_timed {
    local count=0
    local timeout=0

    if [[ -n "${GIT_TIMEOUT}" ]]; then
        timeout=${GIT_TIMEOUT}
    fi

    until timeout -s SIGINT ${timeout} git "$@"; do
        # 124 is timeout(1)'s special return code when it reached the
        # timeout; otherwise assume fatal failure
        if [[ $? -ne 124 ]]; then
            exitcode=$?
            echo $LINENO "git call failed: [git $@]"
            exit $exitcode
        fi

        count=$(($count + 1))
        echo "timeout ${count} for git call: [git $@]"
        if [ $count -eq 3 ]; then
            echo $LINENO "Maximum of 3 git retries reached"
            exit 1
        fi
        sleep 5
    done
}

if [ -z "$GERRIT_SITE" ]; then
    echo "The gerrit site name (eg 'https://review.openstack.org') must be the first argument."
    exit 1
fi

if [ -z "$ZUUL_URL" ]; then
    echo "The ZUUL_URL must be provided."
    exit 1
fi

if [ -z "$GIT_ORIGIN" ] || [ -n "$ZUUL_NEWREV" ]; then
    GIT_ORIGIN="$GERRIT_SITE/p"
    # git://git.openstack.org/
    # https://review.openstack.org/p
fi

if [ -z "$ZUUL_REF" ]; then
    if [ -n "$BRANCH" ]; then
        echo "No ZUUL_REF so using requested branch $BRANCH from origin."
        ZUUL_REF=$BRANCH
        # use the origin since zuul mergers have outdated branches
        ZUUL_URL=$GIT_ORIGIN
    else
        echo "Provide either ZUUL_REF or BRANCH in the calling enviromnent."
        exit 1
    fi
fi

if [ ! -z "$ZUUL_CHANGE" ]; then
    echo "Triggered by: $GERRIT_SITE/$ZUUL_CHANGE"
fi

set -x
if [[ ! -e .git ]]; then
    ls -a
    rm -fr .[^.]* *
    if [ -d /opt/git/$ZUUL_PROJECT/.git ]; then
        git_timed clone file:///opt/git/$ZUUL_PROJECT .
    else
        git_timed clone $GIT_ORIGIN/$ZUUL_PROJECT .
    fi
fi
git remote set-url origin $GIT_ORIGIN/$ZUUL_PROJECT

# attempt to work around bugs 925790 and 1229352
if ! git_timed remote update; then
    echo "The remote update failed, so garbage collecting before trying again."
    git gc
    git_timed remote update
fi

git reset --hard
if ! git clean -x -f -d -q ; then
    sleep 1
    git clean -x -f -d -q
fi

if echo "$ZUUL_REF" | grep -q ^refs/tags/; then
    git_timed fetch --tags $ZUUL_URL/$ZUUL_PROJECT
    git checkout $ZUUL_REF
    git reset --hard $ZUUL_REF
elif [ -z "$ZUUL_NEWREV" ]; then
    git_timed fetch $ZUUL_URL/$ZUUL_PROJECT $ZUUL_REF
    git checkout FETCH_HEAD
    git reset --hard FETCH_HEAD
else
    git checkout $ZUUL_NEWREV
    git reset --hard $ZUUL_NEWREV
fi

if ! git clean -x -f -d -q ; then
    sleep 1
    git clean -x -f -d -q
fi

if [ -f .gitmodules ]; then
    git_timed submodule init
    git_timed submodule sync
    git_timed submodule update --init
fi
