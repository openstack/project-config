#!/bin/bash -xe

# Copyright (C) 2011-2013 OpenStack Foundation
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

HOSTNAME=$1

SUDO=${SUDO:-true}
THIN=${THIN:-true}
ALL_MYSQL_PRIVS=${ALL_MYSQL_PRIVS:-false}
GIT_BASE=${GIT_BASE:-git://git.openstack.org}

sudo hostname $HOSTNAME
if [ -n "$HOSTNAME" ] && ! grep -q $HOSTNAME /etc/hosts ; then
    echo "127.0.1.1 $HOSTNAME" | sudo tee -a /etc/hosts
fi

echo $HOSTNAME > /tmp/image-hostname.txt
sudo mv /tmp/image-hostname.txt /etc/image-hostname.txt

# HP Cloud centos6 images currently require an update to the
# certificates file before they can connect to common services such as
# fedora mirror for EPEL over https
if [ -f /etc/redhat-release ]; then
    if grep -q 'CentOS release 6' /etc/redhat-release; then
        # chicken-and-egg ... hp cloud image has EPEL installed, but
        # we can't connect to it...
        # Note 'epel*' will match 0 or more repositories named epel,
        # so it will work regardless of whether epel is actually
        # installed.
        sudo yum --disablerepo=epel* update -y ca-certificates
    fi
else
    # Cloud provider apt repos break us - so stop using them
    LSBDISTID=$(lsb_release -is)
    LSBDISTCODENAME=$(lsb_release -cs)
    if [ "$LSBDISTID" == "Ubuntu" ] ; then
    sudo dd of=/etc/apt/sources.list <<EOF
# See http://help.ubuntu.com/community/UpgradeNotes for how to upgrade to
# newer versions of the distribution.
deb http://us.archive.ubuntu.com/ubuntu/ $LSBDISTCODENAME main restricted
deb-src http://us.archive.ubuntu.com/ubuntu/ $LSBDISTCODENAME main restricted

## Major bug fix updates produced after the final release of the
## distribution.
deb http://us.archive.ubuntu.com/ubuntu/ $LSBDISTCODENAME-updates main restricted
deb-src http://us.archive.ubuntu.com/ubuntu/ $LSBDISTCODENAME-updates main restricted

## N.B. software from this repository is ENTIRELY UNSUPPORTED by the Ubuntu
## team. Also, please note that software in universe WILL NOT receive any
## review or updates from the Ubuntu security team.
deb http://us.archive.ubuntu.com/ubuntu/ $LSBDISTCODENAME universe
deb-src http://us.archive.ubuntu.com/ubuntu/ $LSBDISTCODENAME universe
deb http://us.archive.ubuntu.com/ubuntu/ $LSBDISTCODENAME-updates universe
deb-src http://us.archive.ubuntu.com/ubuntu/ $LSBDISTCODENAME-updates universe

## N.B. software from this repository is ENTIRELY UNSUPPORTED by the Ubuntu
## team, and may not be under a free licence. Please satisfy yourself as to
## your rights to use the software. Also, please note that software in
## multiverse WILL NOT receive any review or updates from the Ubuntu
## security team.
deb http://us.archive.ubuntu.com/ubuntu/ $LSBDISTCODENAME multiverse
deb-src http://us.archive.ubuntu.com/ubuntu/ $LSBDISTCODENAME multiverse
deb http://us.archive.ubuntu.com/ubuntu/ $LSBDISTCODENAME-updates multiverse
deb-src http://us.archive.ubuntu.com/ubuntu/ $LSBDISTCODENAME-updates multiverse

## N.B. software from this repository may not have been tested as
## extensively as that contained in the main release, although it includes
## newer versions of some applications which may provide useful features.
## Also, please note that software in backports WILL NOT receive any review
## or updates from the Ubuntu security team.
deb http://us.archive.ubuntu.com/ubuntu/ $LSBDISTCODENAME-backports main restricted universe multiverse
deb-src http://us.archive.ubuntu.com/ubuntu/ $LSBDISTCODENAME-backports main restricted universe multiverse

deb http://security.ubuntu.com/ubuntu $LSBDISTCODENAME-security main restricted
deb-src http://security.ubuntu.com/ubuntu $LSBDISTCODENAME-security main restricted
deb http://security.ubuntu.com/ubuntu $LSBDISTCODENAME-security universe
deb-src http://security.ubuntu.com/ubuntu $LSBDISTCODENAME-security universe
deb http://security.ubuntu.com/ubuntu $LSBDISTCODENAME-security multiverse
deb-src http://security.ubuntu.com/ubuntu $LSBDISTCODENAME-security multiverse
EOF
    fi
fi

# Fedora image doesn't come with wget
if [ -f /usr/bin/yum ]; then
    sudo yum -y install wget
fi
wget https://git.openstack.org/cgit/openstack-infra/system-config/plain/install_puppet.sh
sudo bash -xe install_puppet.sh

sudo git clone --depth=1 $GIT_BASE/openstack-infra/system-config.git \
    /root/system-config
sudo /bin/bash /root/system-config/install_modules.sh

set +e
if [ -z "$NODEPOOL_SSH_KEY" ] ; then
    sudo puppet apply --detailed-exitcodes --color=false \
        --modulepath=/root/system-config/modules:/etc/puppet/modules \
        -e "class {'openstack_project::single_use_slave':
                    sudo => $SUDO,
                    thin => $THIN,
                    all_mysql_privs => $ALL_MYSQL_PRIVS,
            }"
    PUPPET_RET_CODE=$?
else
    sudo puppet apply --detailed-exitcodes --color=false \
        --modulepath=/root/system-config/modules:/etc/puppet/modules \
        -e "class {'openstack_project::single_use_slave':
                    install_users => false,
                    sudo => $SUDO,
                    thin => $THIN,
                    all_mysql_privs => $ALL_MYSQL_PRIVS,
                    ssh_key => '$NODEPOOL_SSH_KEY',
            }"
    PUPPET_RET_CODE=$?
fi
# Puppet doesn't properly return exit codes. Check here the values that
# indicate failure of some sort happened. 0 and 2 indicate success.
if [ "$PUPPET_RET_CODE" -eq "4" ] || [ "$PUPPET_RET_CODE" -eq "6" ] ; then
    exit $PUPPET_RET_CODE
fi
set -e

# The puppet modules should install unbound.  Set up some nameservers.
cat >/tmp/forwarding.conf <<EOF
forward-zone:
  name: "."
  forward-addr: 8.8.8.8
EOF
sudo mv /tmp/forwarding.conf /etc/unbound/
sudo chown root:root /etc/unbound/forwarding.conf
sudo chmod a+r /etc/unbound/forwarding.conf
# HPCloud has selinux enabled by default, Rackspace apparently not.
# Regardless, apply the correct context.
if [ -x /sbin/restorecon ] ; then
    sudo chcon system_u:object_r:named_conf_t:s0 /etc/unbound/forwarding.conf
fi

# Overwrite /etc/resolv.conf at boot
sudo dd of=/etc/rc.local <<EOF
#!/bin/bash
set -o xtrace

# Some providers inject dynamic network config statically. Work around this
# for DNS nameservers. This is expected to fail on some nodes so remove -e.
set +e
sed -i -e 's/^\(DNS[0-9]*=[.0-9]\+\)/#\1/g' /etc/sysconfig/network-scripts/ifcfg-*
set -e

echo 'nameserver 127.0.0.1' > /etc/resolv.conf

exit 0
EOF

# hpcloud has started mounting ephemeral /dev/vdb at /mnt.
# devstack-gate wants to partition the ephemeral disk, add some swap
# and mount it at /opt.  get rid of the mount.
#
# note this comes down from the cloud-init metadata; which we setup to
# ignore below.
sudo sed -i '/^\/dev\/vdb/d' /etc/fstab


# Make all cloud-init data sources match rackspace- only attempt to look
# at ConfigDrive, not at metadata service. This is not needed if there
# is no cloud-init
if [ -d /etc/cloud/cloud.cfg.d ] ; then
sudo dd of=/etc/cloud/cloud.cfg.d/95_real_datasources.cfg <<EOF
datasource_list: [ ConfigDrive, None ]
EOF
fi

# reset cloud-init
sudo rm -rf /var/lib/cloud/instances

sudo bash -c "echo 'include: /etc/unbound/forwarding.conf' >> /etc/unbound/unbound.conf"
if [ -e /etc/init.d/unbound ] ; then
    sudo /etc/init.d/unbound restart
elif [ -e /usr/lib/systemd/system/unbound.service ] ; then
    sudo systemctl restart unbound
else
    echo "Can't discover a method to restart \"unbound\""
    exit 1
fi

# Make sure DNS works.
dig git.openstack.org

# Cache all currently known gerrit repos.
sudo mkdir -p /opt/git
sudo -i python /opt/nodepool-scripts/cache_git_repos.py $GIT_BASE

# We don't always get ext4 from our clouds, mount ext3 as ext4 on the next
# boot (eg when this image is used for testing).
sudo sed -i 's/ext3/ext4/g' /etc/fstab

# Remove additional sources used to install puppet or special version of pypi.
# We do this because leaving these sources in place causes every test that
# does an apt-get update to hit those servers which may not have the uptime
# of our local mirrors.
OS_FAMILY=$(facter osfamily)
if [ "$OS_FAMILY" == "Debian" ] ; then
    sudo rm -f /etc/apt/sources.list.d/*
    sudo apt-get update
elif [ "$OS_FAMILY" == "RedHat" ] ; then
    # Can't delete * in yum.repos.d since all of the repos are listed there.
    # Be specific instead.
    if [ -f /etc/yum.repos.d/puppetlabs.repo ] ; then
        sudo rm -f /etc/yum.repos.d/puppetlabs.repo
    fi
fi

# Remove cron jobs
# We create fresh servers for these hosts, and they are used once. They don't
# need to do things like update the locatedb or the mandb or rotate logs
# or really any of those things. We only want code running here that we want
# here.
sudo rm -f /etc/cron.{monthly,weekly,daily,hourly,d}/*

# Install Zuul into a virtualenv
# This is in /usr instead of /usr/local due to this bug on precise:
# https://bugs.launchpad.net/ubuntu/+source/python2.7/+bug/839588
git clone /opt/git/openstack-infra/zuul /tmp/zuul
sudo virtualenv /usr/zuul-env
sudo -H /usr/zuul-env/bin/pip install /tmp/zuul
sudo rm -fr /tmp/zuul

# Create a virtualenv for zuul-swift-logs
# This is in /usr instead of /usr/local due to this bug on precise:
# https://bugs.launchpad.net/ubuntu/+source/python2.7/+bug/839588
sudo -H virtualenv /usr/zuul-swift-logs-env
sudo -H /usr/zuul-swift-logs-env/bin/pip install python-magic argparse \
    requests glob2

# Create a virtualenv for os-testr (which contains subunit2html)
# this is in /usr instead of /usr/loca/ due to this bug on precise:
# https://bugs.launchpad.net/ubuntu/+source/python2.7/+bug/839588
sudo -H virtualenv /usr/os-testr-env
sudo -H /usr/os-testr-env/bin/pip install os-testr
