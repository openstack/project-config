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
NODEPOOL_CENTOS_MIRROR=${NODEPOOL_CENTOS_MIRROR:-http://$NODEPOOL_MIRROR_HOST/centos}
NODEPOOL_EPEL_MIRROR=${NODEPOOL_EPEL_MIRROR:-http://$NODEPOOL_MIRROR_HOST/epel}
NODEPOOL_CEPH_MIRROR=${NODEPOOL_CEPH_MIRROR:-http://$NODEPOOL_MIRROR_HOST/ceph-deb-hammer}
NODEPOOL_NPM_MIRROR=${NODEPOOL_NPM_MIRROR:-http://$NODEPOOL_MIRROR_HOST/npm/}

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

cat >/home/jenkins/.npmrc <<EOF
registry = $NODEPOOL_NPM_MIRROR

# Retry settings
fetch-retries=10              # The number of times to retry getting a package.
fetch-retry-mintimeout=60000  # Minimum fetch timeout: 1 minute (default 10 seconds)
fetch-retry-maxtimeout=300000 # Maximum fetch timeout: 5 minute (default 1 minute)
EOF


# Double check that when the node is made ready it is able
# to resolve names against DNS.
host git.openstack.org
host $NODEPOOL_MIRROR_HOST

LSBDISTID=$(lsb_release -is)
LSBDISTCODENAME=$(lsb_release -cs)
# NOTE(pabelanger): We don't actually have mirrors for ubuntu-precise, so skip
# them.
if [ "$LSBDISTID" == "Ubuntu" ] && [ "$LSBDISTCODENAME" != 'precise' ]; then
        sudo dd of=/etc/apt/sources.list <<EOF
deb $NODEPOOL_UBUNTU_MIRROR $LSBDISTCODENAME main universe
deb $NODEPOOL_UBUNTU_MIRROR $LSBDISTCODENAME-updates main universe
deb $NODEPOOL_UBUNTU_MIRROR $LSBDISTCODENAME-backports main universe
deb $NODEPOOL_UBUNTU_MIRROR $LSBDISTCODENAME-security main universe
EOF
    sudo dd of=/etc/apt/sources.list.d/ceph-deb-hammer.list <<EOF
deb $NODEPOOL_CEPH_MIRROR $LSBDISTCODENAME main
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
elif [ "$LSBDISTID" == "CentOS" ]; then
    sudo dd of=/etc/yum.repos.d/CentOS-Base.repo <<EOF
[base]
name=CentOS-\$releasever - Base
baseurl=$NODEPOOL_CENTOS_MIRROR/\$releasever/os/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-\$releasever

#released updates
[updates]
name=CentOS-\$releasever - Updates
baseurl=$NODEPOOL_CENTOS_MIRROR/\$releasever/updates/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-\$releasever

#additional packages that may be useful
[extras]
name=CentOS-\$releasever - Extras
baseurl=$NODEPOOL_CENTOS_MIRROR/\$releasever/extras/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-\$releasever
EOF

    sudo dd of=/etc/yum.repos.d/epel.repo <<EOF
[epel]
name=Extra Packages for Enterprise Linux \$releasever - \$basearch
baseurl=$NODEPOOL_EPEL_MIRROR/\$releasever/\$basearch
failovermethod=priority
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-\$releasever
EOF
fi
