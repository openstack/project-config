#!/bin/bash -e

function print_help {
    echo ""
    echo "USAGE:"
    echo " ./eol_branch.sh [options] branch eol_tag project [project [project [...]]]"
    echo ""
    echo "A tool for retiring old branches. Performs the following:"
    echo "1) Abandon stale reviews,"
    echo "2) tag current position of branch"
    echo "3) delete the branch from the remote"
    echo ""
    echo "Must be ran from a directory containing a recent checkout of the project[s]"
    echo ""
    echo "Options:"
    echo " -d, --dry-run           Do not run any harmful commands"
    echo " --eol-message <message> Set the message on the end-of-life tag"
    echo " -h, --help              This help message"
    echo " -q, --quiet             Turn off unimportant messages"
    echo " --remote <remote>       Set the remote to delete branches from (default: gerrit)"
    echo " -w, --warn-exit         Exit on any warnings"
    echo ""
}

OPTS=`getopt -o dhqw --long eol-message:,dry-run,help,quiet,remote:,warn-exit -n $0 -- "$@"`
if [ $? != 0 ] ; then
    echo "Failed parsing options." >&2
    print_help
    exit 1
fi
eval set -- "$OPTS"
set -e
# Defaults:
EOL_MESSAGE=""
DEBUG=
REMOTE=gerrit
VERBOSE=true
WARN_EXIT=false

while true; do
    case "$1" in
        -d|--dry-run)
            DEBUG=echo
            shift
            ;;
        --eol-message)
            EOL_MESSAGE=$2
            shift
            shift
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        -q|--quiet)
            VERBOSE=false
            shift
            ;;
        --remote)
            REMOTE=$2
            shift
            shift
            ;;
        -w|--warn-exit)
            WARN_EXIT=true
            shift
            ;;
        --)
            shift
            break
            ;;
    esac
done

# First argument is the branch to delete
BRANCH=$1
shift

# Second argument is the tag to use before deletion
TAG=$1
shift

if [$EOL_MESSAGE = ""]; then
    EOL_MESSAGE="This branch ($BRANCH) is at End Of Life"
fi


function abandon_reviews {
    project=$1
    if [ $VERBOSE = true ]; then
        echo "Running query: status:open project:$project branch:$BRANCH"
    fi

    gerrit_query="--current-patch-set status:open project:$project branch:$BRANCH"
    revisions=($(ssh -p 29418 review.openstack.org gerrit query $gerrit_query |
        grep '^    revision: [a-f0-9]\{40\}$' | cut -b 15-))
    for rev in "${revisions[@]}"; do
        if [ $VERBOSE = true ]; then
            echo "Found commit $rev to abandon"
        fi
        $DEBUG ssh -p 29418 review.openstack.org gerrit review --project $project --abandon --message \"$EOL_MESSAGE\" $rev
    done
}

function tag_eol {
    project=$1
    rev=`git rev-parse remotes/$REMOTE/$BRANCH`

    if git rev-parse $TAG >/dev/null 2>&1; then
        echo "WARN: The tag ($TAG) already exists on $project"
        tag_rev=`git rev-list -n 1 $TAG`
        if [ $rev != $tag_rev ]; then
            echo "ERROR: The tag ($tag_rev) doesn't match the branch ($rev)"
            exit 1
        fi
        return 0
    fi

    if [ $VERBOSE = true ]; then
        echo "About to add tag $TAG to $project at branch $BRANCH (rev $rev)"
    fi
    $DEBUG git tag -s $TAG -m "$EOL_MESSAGE" remotes/$REMOTE/$BRANCH
    $DEBUG git push gerrit $TAG
}

function delete_branch {
    rev=`git rev-parse remotes/$REMOTE/$BRANCH`
    if [ $VERBOSE = true ]; then
        echo "About to delete the branch $BRANCH from $project (rev $rev)"
    fi
    $DEBUG git push $REMOTE --delete refs/heads/$BRANCH
}

function warning_message {
    echo "WARNING: $1"
    if [ $WARN_EXIT = true ]; then
        exit 1
    fi
}

while (( "$#" )); do
    project=$1
    shift

    if ! [ -d $project/.git ]; then
        if ! [ -d $project ]; then
            echo "$project not found on filesystem. Will attempt to clone"
            $DEBUG git clone git://git.openstack.org/$project $project
        else
            warning_message "$project is not a git repo"
            echo "skipping..."
            continue
        fi
    fi

    pushd $project

    if ! git config remote.$REMOTE.url >/dev/null 2>&1; then
        if ! [ -f .gitreview ]; then
            # Work around projects with missing .gitreview files. This usually
            # happens when a probject is no longer maintained.
            user=`git config --global gitreview.username`
            warning_message "Guessing remote manually"
            git remote add $REMOTE ssh://$user@review.openstack.org:29418/$project.git
        else
            git review -s
        fi
    fi

    # Add some hardening around incorrect looking remote url's
    remote_url=`git config --get remote.$REMOTE.url`
    if [[ $remote_url != *"$project.git" && $remote_url != *"$project" ]]; then
        warning_message "The url for remote $REMOTE does not end with $project or
        $project.git. This may be deliberate, but it's more likely that the
        project has a mis-configured .gitreview file pointing to the wrong
        repository. This is the case in many of the (now retired) deb-* packages
        where their remotes were set to the upstream project instead of their own
        deb repository."
        echo "skipping..."
        popd
        continue
    fi

    git remote update --prune

    if ! git rev-parse remotes/$REMOTE/$BRANCH >/dev/null 2>&1; then
        warning_message "$project does not have a branch $BRANCH"
        echo "skipping..."
        popd
        continue
    fi

    abandon_reviews $project
    tag_eol $project
    delete_branch $project

    popd
done
