#!/bin/bash -xe

# set a default path to the preinstalled bindep entrypoint
export BINDEP=${BINDEP:-/usr/bindep-env/bin/bindep}

function is_fedora {
    [ -f /usr/bin/yum ] && cat /etc/*release | grep -q -e "Fedora"
}

YUM=yum
if is_fedora; then
    YUM=dnf
fi

# figure out which bindep list to use
if [ -n "$PACKAGES" ] ; then
    # already set in the calling environment
    :
elif [ -e bindep.txt ] ; then
    # project has its own bindep list
    export PACKAGES=bindep.txt
elif [ -e other-requirements.txt ] ; then
    # project has its own bindep list
    export PACKAGES=other-requirements.txt
else
    # use the bindep fallback list preinstalled on the worker
    export PACKAGES=/usr/local/jenkins/common_data/bindep-fallback.txt
fi

# an install loop, retrying to check that all requested packages are obtained
try=0
# Install test profile using bindep
until $BINDEP -b -f $PACKAGES test; do
    if [ $try -gt 2 ] ; then
        set +x
        echo -e "\nERROR: These requested packages were not installed:\n" \
            "\n`$BINDEP -b -f $PACKAGES test`\n" 1>&2
        set -x
        exit 1
    fi

    # don't abort inside the loop, we check for the desired outcome
    set +e
    if apt-get -v >/dev/null 2>&1 ; then
        sudo apt-get -qq update
        sudo PATH=/usr/sbin:/sbin:$PATH DEBIAN_FRONTEND=noninteractive \
            apt-get -q --option "Dpkg::Options::=--force-confold" \
            --assume-yes install `$BINDEP -b -f $PACKAGES test`
    elif emerge --version >/dev/null 2>&1 ; then
        sudo emerge -uDNq --jobs=4 @world
        sudo PATH=/usr/sbin:/sbin:$PATH emerge -q --jobs=4 \
            `$BINDEP -b -f $PACKAGES`
    elif zypper --version >/dev/null 2>&1 ; then
        sudo PATH=/usr/sbin:/sbin:$PATH zypper --non-interactive install \
            `$BINDEP -b -f $PACKAGES test`
    else
        sudo PATH=/usr/sbin:/sbin:$PATH $YUM install -y \
            `$BINDEP -b -f $PACKAGES test`
    fi
    set -e

    try=$(( $try+1 ))
done
