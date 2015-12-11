#!/bin/bash -xe

# figure out which bindep list to use
if [ -e other-requirements.txt ] ; then
    # project has its own bindep list
    export DISTRO_PACKAGES=other-requirements.txt
elif [ "$ZUUL_PROJECT" == "openstack-infra/project-config" ] ; then
    # test changes to the included fallback list in project-config jobs
    export DISTRO_PACKAGES=jenkins/data/bindep-fallback.txt
else
    # use the bindep fallback list preinstalled on the worker
    export DISTRO_PACKAGES=/usr/local/jenkins/common_data/bindep-fallback.txt
fi

# install all requested packages from the appropriate bindep list
if apt-get -v >/dev/null ; then
    sudo apt-get update
    sudo PATH=/usr/sbin:/sbin:$PATH DEBIAN_FRONTEND=noninteractive \
        apt-get --option "Dpkg::Options::=--force-confold" \
        --assume-yes install \
        `/usr/bindep-env/bin/bindep -b -f $DISTRO_PACKAGES || true`
else
    sudo PATH=/usr/sbin:/sbin:$PATH yum install -y \
        `/usr/bindep-env/bin/bindep -b -f $DISTRO_PACKAGES || true`
fi
