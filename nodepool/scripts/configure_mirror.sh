#!/bin/bash -xe

# Copyright (C) 2014 Hewlett-Packard Development Company, L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
#
# See the License for the specific language governing permissions and
# limitations under the License.

source /etc/nodepool/provider

# Generate the AFS Slug from the host system.
source /usr/local/jenkins/slave_scripts/afs-slug.sh

NODEPOOL_MIRROR_HOST=${NODEPOOL_MIRROR_HOST:-mirror.$NODEPOOL_REGION.$NODEPOOL_CLOUD.openstack.org}
NODEPOOL_MIRROR_HOST=$(echo $NODEPOOL_MIRROR_HOST|tr '[:upper:]' '[:lower:]')
NODEPOOL_PYPI_MIRROR=${NODEPOOL_PYPI_MIRROR:-http://$NODEPOOL_MIRROR_HOST/pypi/simple}
NODEPOOL_WHEEL_MIRROR=${NODEPOOL_WHEEL_MIRROR:-http://$NODEPOOL_MIRROR_HOST/wheel/$AFS_SLUG}
NODEPOOL_UBUNTU_MIRROR=${NODEPOOL_UBUNTU_MIRROR:-http://$NODEPOOL_MIRROR_HOST/ubuntu}

cat >/tmp/pip.conf <<EOF
[global]
timeout = 60
index-url = $NODEPOOL_PYPI_MIRROR
trusted-host = $NODEPOOL_MIRROR_HOST
extra-index-url = $NODEPOOL_WHEEL_MIRROR
EOF
sudo mv /tmp/pip.conf /etc/pip.conf

cat >/home/jenkins/.pydistutils.cfg <<EOF
[easy_install]
index_url = $NODEPOOL_PYPI_MIRROR
allow_hosts = *.openstack.org
EOF

# Double check that when the node is made ready it is able
# to resolve names against DNS.
host git.openstack.org
host $NODEPOOL_MIRROR_HOST

LSBDISTID=$(lsb_release -is)
LSBDISTCODENAME=$(lsb_release -cs)
if [ "$LSBDISTID" == "Ubuntu" ] ; then
    sudo dd of=/etc/apt/sources.list <<EOF
deb $NODEPOOL_UBUNTU_MIRROR $LSBDISTCODENAME main universe
deb $NODEPOOL_UBUNTU_MIRROR $LSBDISTCODENAME-updates main universe
deb $NODEPOOL_UBUNTU_MIRROR $LSBDISTCODENAME-backports main universe
deb $NODEPOOL_UBUNTU_MIRROR $LSBDISTCODENAME-security main universe
EOF
    if [ "$LSBDISTCODENAME" != 'precise' ] ; then
        # Turn off multi-arch
        sudo dpkg --remove-architecture i386
    fi
    # Turn off checking of GPG signatures
    sudo dd of=/etc/apt/apt.conf.d/99unauthenticated <<EOF
APT::Get::AllowUnauthenticated "true";
EOF
elif [ "$LSBDISTID" == "Debian" ] ; then
sudo dd of=/etc/apt/sources.list <<EOF
deb http://httpredir.debian.org/debian $LSBDISTCODENAME main
deb-src http://httpredir.debian.org/debian $LSBDISTCODENAME main

deb http://httpredir.debian.org/debian $LSBDISTCODENAME-updates main
deb-src http://httpredir.debian.org/debian $LSBDISTCODENAME-updates main

deb http://security.debian.org/ $LSBDISTCODENAME/updates main
deb-src http://security.debian.org/ $LSBDISTCODENAME/updates main

deb http://httpredir.debian.org/debian $LSBDISTCODENAME-backports main
deb-src http://httpredir.debian.org/debian $LSBDISTCODENAME-backports main
EOF
fi
