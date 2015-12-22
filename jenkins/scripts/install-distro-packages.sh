#!/bin/bash -xe

# set a default path to the preinstalled bindep entrypoint
export BINDEP=${BINDEP:-/usr/bindep-env/bin/bindep}

# figure out which bindep list to use
if [ -n "$PACKAGES" ] ; then
    # already set in the calling environment
    :
elif [ -e other-requirements.txt ] ; then
    # project has its own bindep list
    export PACKAGES=other-requirements.txt
else
    # use the bindep fallback list preinstalled on the worker
    export PACKAGES=/usr/local/jenkins/common_data/bindep-fallback.txt
fi

# an install loop, retrying to check that all requested packages are obtained
try=0
until $BINDEP -b -f $PACKAGES ; do
    if [ $try -gt 2 ] ; then
        set +x
        echo -e "\nERROR: These requested packages were not installed:\n" \
            "\n`$BINDEP -b -f $PACKAGES`\n" 1>&2
        set -x
        exit 1
    fi

    # don't abort inside the loop, we check for the desired outcome
    set +e
    if apt-get -v >/dev/null ; then
        sudo apt-get update
        sudo PATH=/usr/sbin:/sbin:$PATH DEBIAN_FRONTEND=noninteractive \
            apt-get --option "Dpkg::Options::=--force-confold" \
            --assume-yes install `$BINDEP -b -f $PACKAGES`
    else
        sudo PATH=/usr/sbin:/sbin:$PATH yum install -y \
            `$BINDEP -b -f $PACKAGES`
    fi
    set -e

    try=$(( $try+1 ))
done
