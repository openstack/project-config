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

if [ -f /etc/dib-builddate.txt ]; then
    echo "Image build date"
    echo "================"
    cat /etc/dib-builddate.txt
fi

source /etc/nodepool/provider

NODEPOOL_MIRROR_HOST=${NODEPOOL_MIRROR_HOST:-mirror.$NODEPOOL_REGION.$NODEPOOL_CLOUD.openstack.org}
NODEPOOL_MIRROR_HOST=$(echo $NODEPOOL_MIRROR_HOST|tr '[:upper:]' '[:lower:]')

# Write the default value for NODEPOOL_MIRROR_HOST into the mirror_info
# script first. This allows us to set a default while allowing consumers
# to override values if necessary.
echo "export NODEPOOL_MIRROR_HOST=\${NODEPOOL_MIRROR_HOST:-$NODEPOOL_MIRROR_HOST}" > /tmp/mirror_info.sh
# Copy AFS Slug generation details into mirror_info.sh so that consumers
# don't have to know about generating the wheel mirror's
# distro-release-processor tuple.
cat /usr/local/jenkins/slave_scripts/afs-slug.sh >> /tmp/mirror_info.sh
# We write this as a heredoc so that the same information used by this script
# is useable by others without double accounting. Note that the quoted EOF
# means we don't do variable expansion.
cat << "EOF" >> /tmp/mirror_info.sh
export NODEPOOL_DEBIAN_MIRROR=${NODEPOOL_DEBIAN_MIRROR:-http://$NODEPOOL_MIRROR_HOST/debian}
export NODEPOOL_PYPI_MIRROR=${NODEPOOL_PYPI_MIRROR:-http://$NODEPOOL_MIRROR_HOST/pypi/simple}
export NODEPOOL_WHEEL_MIRROR=${NODEPOOL_WHEEL_MIRROR:-http://$NODEPOOL_MIRROR_HOST/wheel/$AFS_SLUG}
export NODEPOOL_UBUNTU_MIRROR=${NODEPOOL_UBUNTU_MIRROR:-http://$NODEPOOL_MIRROR_HOST/ubuntu}
export NODEPOOL_CENTOS_MIRROR=${NODEPOOL_CENTOS_MIRROR:-http://$NODEPOOL_MIRROR_HOST/centos}
export NODEPOOL_DEBIAN_OPENSTACK_MIRROR=${NODEPOOL_DEBIAN_OPENSTACK_MIRROR:-http://$NODEPOOL_MIRROR_HOST/debian-openstack}
export NODEPOOL_EPEL_MIRROR=${NODEPOOL_EPEL_MIRROR:-http://$NODEPOOL_MIRROR_HOST/epel}
export NODEPOOL_FEDORA_MIRROR=${NODEPOOL_FEDORA_MIRROR:-http://$NODEPOOL_MIRROR_HOST/fedora}
export NODEPOOL_OPENSUSE_MIRROR=${NODEPOOL_OPENSUSE_MIRROR:-http://$NODEPOOL_MIRROR_HOST/opensuse}
export NODEPOOL_CEPH_MIRROR=${NODEPOOL_CEPH_MIRROR:-http://$NODEPOOL_MIRROR_HOST/ceph-deb-hammer}
export NODEPOOL_UCA_MIRROR=${NODEPOOL_UCA_MIRROR:-http://$NODEPOOL_MIRROR_HOST/ubuntu-cloud-archive}
export NODEPOOL_MARIADB_MIRROR=${NODEPOOL_MARIADB_MIRROR:-http://$NODEPOOL_MIRROR_HOST/ubuntu-mariadb}
# Reverse proxy servers
export NODEPOOL_DOCKER_REGISTRY_PROXY=${NODEPOOL_DOCKER_REGISTRY_PROXY:-http://$NODEPOOL_MIRROR_HOST:8081/registry-1.docker}
export NODEPOOL_RDO_PROXY=${NODEPOOL_RDO_PROXY:-http://$NODEPOOL_MIRROR_HOST:8080/rdo}
EOF

sudo mkdir -p /etc/ci
sudo mv /tmp/mirror_info.sh /etc/ci/mirror_info.sh
source /etc/ci/mirror_info.sh

LSBDISTID=$(lsb_release -is)
LSBDISTCODENAME=$(lsb_release -cs)

# Double check that when the node is made ready it is able
# to resolve names against DNS.
# NOTE(pabelanger): Because it is possible for nodepool to SSH into a node but
# DNS has not been fully started, we try up to 300 seconds (10 attempts) to
# resolve DNS once.
for COUNT in {1..10}; do
    set +e
    host -W 30 git.openstack.org
    res=$?
    set -e
    if [ $res == 0 ]; then
        break
    elif [ $COUNT == 10 ]; then
        exit 1
    fi
done
host $NODEPOOL_MIRROR_HOST

PIP_CONF="\
[global]
timeout = 60
index-url = $NODEPOOL_PYPI_MIRROR
trusted-host = $NODEPOOL_MIRROR_HOST
extra-index-url = $NODEPOOL_WHEEL_MIRROR"

PYDISTUTILS_CFG="\
[easy_install]
index_url = $NODEPOOL_PYPI_MIRROR
allow_hosts = *.openstack.org"

UBUNTU_SOURCES_LIST="\
deb $NODEPOOL_UBUNTU_MIRROR $LSBDISTCODENAME main universe
deb $NODEPOOL_UBUNTU_MIRROR $LSBDISTCODENAME-updates main universe
deb $NODEPOOL_UBUNTU_MIRROR $LSBDISTCODENAME-backports main universe
deb $NODEPOOL_UBUNTU_MIRROR $LSBDISTCODENAME-security main universe"

CEPH_SOURCES_LIST="deb $NODEPOOL_CEPH_MIRROR $LSBDISTCODENAME main"

UCA_SOURCES_LIST_LIBERTY="deb $NODEPOOL_UCA_MIRROR trusty-updates/liberty main"
UCA_SOURCES_LIST_MITAKA="deb $NODEPOOL_UCA_MIRROR trusty-updates/mitaka main"
UCA_SOURCES_LIST_NEWTON="deb $NODEPOOL_UCA_MIRROR xenial-updates/newton main"
UCA_SOURCES_LIST_OCATA="deb $NODEPOOL_UCA_MIRROR xenial-updates/ocata main"
UCA_SOURCES_LIST_PIKE="deb $NODEPOOL_UCA_MIRROR xenial-updates/pike main"

MARIADB_SOURCES_LIST_10_0="deb $NODEPOOL_MARIADB_MIRROR/10.0 $LSBDISTCODENAME main"
MARIADB_SOURCES_LIST_10_1="deb $NODEPOOL_MARIADB_MIRROR/10.1 $LSBDISTCODENAME main"

APT_CONF_UNAUTHENTICATED="APT::Get::AllowUnauthenticated \"true\";"

DEBIAN_DEFAULT_SOURCES_LIST="\
deb $NODEPOOL_DEBIAN_MIRROR $LSBDISTCODENAME main
deb-src $NODEPOOL_DEBIAN_MIRROR $LSBDISTCODENAME main"

DEBIAN_UPDATES_SOURCES_LIST="\
deb $NODEPOOL_DEBIAN_MIRROR $LSBDISTCODENAME-updates main
deb-src $NODEPOOL_DEBIAN_MIRROR $LSBDISTCODENAME-updates main"

DEBIAN_BACKPORTS_SOURCES_LIST="\
deb $NODEPOOL_DEBIAN_MIRROR $LSBDISTCODENAME-backports main
deb-src $NODEPOOL_DEBIAN_MIRROR $LSBDISTCODENAME-backports main"

DEBIAN_SECURITY_SOURCES_LIST="\
deb $NODEPOOL_DEBIAN_MIRROR $LSBDISTCODENAME-security main
deb-src $NODEPOOL_DEBIAN_MIRROR $LSBDISTCODENAME-security main"

DEBIAN_OPENSTACK_NEWTON_SOURCES_LIST="\
deb $NODEPOOL_DEBIAN_OPENSTACK_MIRROR $LSBDISTCODENAME-newton main
deb $NODEPOOL_DEBIAN_OPENSTACK_MIRROR $LSBDISTCODENAME-newton-backports main"

YUM_REPOS_FEDORA="\
[fedora]
name=Fedora \$releasever - \$basearch
failovermethod=priority
baseurl=$NODEPOOL_FEDORA_MIRROR/releases/\$releasever/Everything/\$basearch/os/
enabled=1
metadata_expire=7d
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
skip_if_unavailable=False
deltarpm=False
deltarpm_percentage=0"

YUM_REPOS_FEDORA_UPDATES="\
[updates]
name=Fedora \$releasever - \$basearch - Updates
failovermethod=priority
baseurl=$NODEPOOL_FEDORA_MIRROR/updates/\$releasever/\$basearch/
enabled=1
gpgcheck=1
metadata_expire=6h
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-\$releasever-\$basearch
skip_if_unavailable=False
deltarpm=False
deltarpm_percentage=0"

YUM_REPOS_CENTOS_BASE="\
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
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-\$releasever"

YUM_REPOS_EPEL="\
[epel]
name=Extra Packages for Enterprise Linux \$releasever - \$basearch
baseurl=$NODEPOOL_EPEL_MIRROR/\$releasever/\$basearch
failovermethod=priority
enabled=0
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-\$releasever"

# Write global pip configuration
echo "$PIP_CONF" >/tmp/pip.conf
sudo mv /tmp/pip.conf /etc/
sudo chown root:root /etc/pip.conf
sudo chmod 0644 /etc/pip.conf

# NOTE(pabelanger): We can remove the jenkins user once we have migrated
# nl01.o.o to production
# Write jenkins user distutils/setuptools configuration used by easy_install
echo "$PYDISTUTILS_CFG" | sudo tee /home/jenkins/.pydistutils.cfg
sudo chown jenkins:jenkins /home/jenkins/.pydistutils.cfg

# Write zuul user distutils/setuptools configuration used by easy_install
echo "$PYDISTUTILS_CFG" | sudo tee /home/zuul/.pydistutils.cfg
sudo chown zuul:zuul /home/zuul/.pydistutils.cfg

if [ "$LSBDISTID" == "Ubuntu" ]; then
    echo "$UBUNTU_SOURCES_LIST" >/tmp/sources.list
    sudo mv /tmp/sources.list /etc/apt/
    sudo chown root:root /etc/apt/sources.list
    sudo chmod 0644 /etc/apt/sources.list

    # Opt in repos. Jobs that want to take advantage of them can copy or
    # symlink them into /etc/apt/sources.list.d/
    sudo mkdir -p /etc/apt/sources.list.available.d

    # Ceph
    echo "$CEPH_SOURCES_LIST" >/tmp/ceph-deb-hammer.list
    sudo mv /tmp/ceph-deb-hammer.list /etc/apt/sources.list.available.d/

    # Ubuntu Cloud Archive
    echo "$UCA_SOURCES_LIST_LIBERTY" >/tmp/ubuntu-cloud-archive-liberty.list
    sudo mv /tmp/ubuntu-cloud-archive-liberty.list /etc/apt/sources.list.available.d/

    echo "$UCA_SOURCES_LIST_MITAKA" >/tmp/ubuntu-cloud-archive-mitaka.list
    sudo mv /tmp/ubuntu-cloud-archive-mitaka.list /etc/apt/sources.list.available.d/

    echo "$UCA_SOURCES_LIST_NEWTON" >/tmp/ubuntu-cloud-archive-newton.list
    sudo mv /tmp/ubuntu-cloud-archive-newton.list /etc/apt/sources.list.available.d/

    echo "$UCA_SOURCES_LIST_OCATA" >/tmp/ubuntu-cloud-archive-ocata.list
    sudo mv /tmp/ubuntu-cloud-archive-ocata.list /etc/apt/sources.list.available.d/

    echo "$UCA_SOURCES_LIST_PIKE" >/tmp/ubuntu-cloud-archive-pike.list
    sudo mv /tmp/ubuntu-cloud-archive-pike.list /etc/apt/sources.list.available.d/

    # Ubuntu Mariadb
    echo "$MARIADB_SOURCES_LIST_10_0" >/tmp/ubuntu-mariadb-10-0.list
    sudo mv /tmp/ubuntu-mariadb-10-0.list /etc/apt/sources.list.available.d/

    echo "$MARIADB_SOURCES_LIST_10_1" >/tmp/ubuntu-mariadb-10-1.list
    sudo mv /tmp/ubuntu-mariadb-10-1.list /etc/apt/sources.list.available.d/

    sudo chown root:root /etc/apt/sources.list.available.d/*
    sudo chmod 0644 /etc/apt/sources.list.available.d/*

    # Turn off multi-arch
    sudo dpkg --remove-architecture i386

    # Turn off checking of GPG signatures
    echo "$APT_CONF_UNAUTHENTICATED" >/tmp/99unauthenticated
    sudo mv /tmp/99unauthenticated /etc/apt/apt.conf.d/
    sudo chown root:root /etc/apt/apt.conf.d/99unauthenticated
    sudo chmod 0644 /etc/apt/apt.conf.d/99unauthenticated

elif [ "$LSBDISTID" == "Debian" ] ; then
    echo "$DEBIAN_DEFAULT_SOURCES_LIST" >/tmp/default.list
    sudo mv /tmp/default.list /etc/apt/sources.list.d/
    echo "$DEBIAN_UPDATES_SOURCES_LIST" >/tmp/updates.list
    sudo mv /tmp/updates.list /etc/apt/sources.list.d/
    echo "$DEBIAN_BACKPORTS_SOURCES_LIST" >/tmp/backports.list
    sudo mv /tmp/backports.list /etc/apt/sources.list.d/
    echo "$DEBIAN_SECURITY_SOURCES_LIST" >/tmp/security.list
    sudo mv /tmp/security.list /etc/apt/sources.list.d/

    sudo chown root:root /etc/apt/sources.list.d/*.list
    sudo chmod 0644 /etc/apt/sources.list.d/*.list

    # Opt in repos. Jobs that want to take advantage of them can copy or
    # symlink them into /etc/apt/sources.list.d/
    sudo mkdir -p /etc/apt/sources.list.available.d

    # Debian OpenStack Newton
    echo "$DEBIAN_OPENSTACK_NEWTON_SOURCES_LIST" >/tmp/debian-openstack-newton.list
    sudo mv /tmp/debian-openstack-newton.list /etc/apt/sources.list.available.d/

    sudo chown root:root /etc/apt/sources.list.available.d/*
    sudo chmod 0644 /etc/apt/sources.list.available.d/*

    # Turn off checking of GPG signatures
    echo "$APT_CONF_UNAUTHENTICATED" >/tmp/99unauthenticated
    sudo mv /tmp/99unauthenticated /etc/apt/apt.conf.d/
    sudo chown root:root /etc/apt/apt.conf.d/99unauthenticated
    sudo chmod 0644 /etc/apt/apt.conf.d/99unauthenticated

elif [ "$LSBDISTID" == "CentOS" ]; then
    echo "$YUM_REPOS_CENTOS_BASE" >/tmp/CentOS-Base.repo
    sudo mv /tmp/CentOS-Base.repo /etc/yum.repos.d/
    echo "$YUM_REPOS_EPEL" >/tmp/epel.repo
    sudo mv /tmp/epel.repo /etc/yum.repos.d/
    sudo chown root:root /etc/yum.repos.d/*
    sudo chmod 0644 /etc/yum.repos.d/*

elif [ "$LSBDISTID" == "Fedora" ]; then
    echo "$YUM_REPOS_FEDORA" >/tmp/fedora.repo
    sudo mv /tmp/fedora.repo /etc/yum.repos.d/
    echo "$YUM_REPOS_FEDORA_UPDATES" >/tmp/fedora-updates.repo
    sudo mv /tmp/fedora-updates.repo /etc/yum.repos.d/
    sudo chown root:root /etc/yum.repos.d/*
    sudo chmod 0644 /etc/yum.repos.d/*
elif [ "$LSBDISTID" == "openSUSE project" ]; then
    sudo sed -i -e "s,http://download.opensuse.org/,$NODEPOOL_OPENSUSE_MIRROR/," /etc/zypp/repos.d/*.repo
fi

if [ "$LSBDISTID" == "Debian" ] || [ "$LSBDISTID" == "Ubuntu" ]; then
    # Make sure our indexes are up to date.
    sudo apt-get update
fi
