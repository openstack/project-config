#!/bin/bash
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
# This script takes bits from devstack-gate/functions/cleanup_host in a
# more generic approach, so we don't need to actually run devstack on the node
# to cleanup an host.

set -o xtrace
set -o errexit

LOG_DIR=$WORKSPACE/logs

mkdir $WORKSPACE/logs

# PROJECTS
#  - for each entry, we will probe /etc/${project} and /var/log/${project}
#    and copy out files
#
# For right now, we populate our projects with a guess from those that
# have puppet modules installed.  revisit this if needs change
for project in /etc/puppet/modules/*; do
    # find Puppet OpenStack modules
    if [ -f $project/metadata.json ]; then
        if grep -q 'github.com/openstack/puppet' $project/metadata.json; then
            PROJECTS+="$(basename $project) "
        fi
    fi
done

function is_fedora {
    # note we consider CentOS 7 as fedora for now
    lsb_release -i 2>/dev/null | grep -iq "fedora" || \
        lsb_release -i 2>/dev/null | grep -iq "CentOS"
}

function uses_debs {
    # check if apt-get is installed, valid for debian based
    type "apt-get" 2>/dev/null
}

# Archive the project config & logs
mkdir $LOG_DIR/etc/
for p in $PROJECTS; do
    if [ -d /etc/$p ]; then
        sudo cp -r /etc/$p $LOG_DIR/etc/
    fi
    if [ -d /var/log/$p ]; then
        sudo cp -r /var/log/$p $LOG_DIR
    fi
done

#
# Extra bits and pieces follow
#

# system logs
if uses_debs; then
    sudo cp /var/log/syslog $LOG_DIR/syslog.txt
    sudo cp /var/log/kern.log $LOG_DIR/kern_log.txt
elif is_fedora; then
    sudo journalctl --no-pager > $LOG_DIR/syslog.txt
fi

# rabbitmq logs
if [ -d /var/log/rabbitmq ]; then
    sudo cp -r /var/log/rabbitmq $LOG_DIR
fi

# db logs
if [ -d /var/log/postgresql ] ; then
    # Rename log so it doesn't have an additional '.' so it won't get
    # deleted
    sudo cp /var/log/postgresql/*log $LOG_DIR/postgres.log
fi
if [ -f /var/log/mysql.err ] ; then
    sudo cp /var/log/mysql.err $LOG_DIR/mysql_err.log
fi
if [ -f /var/log/mysql.log ] ; then
    sudo cp /var/log/mysql.log $LOG_DIR/
fi

# libvirt
if [ -d /var/log/libvirt ] ; then
    sudo cp -r /var/log/libvirt $LOG_DIR/
fi

# sudo config
sudo cp -r /etc/sudoers.d $LOG_DIR/
sudo cp /etc/sudoers $LOG_DIR/sudoers.txt

# apache logs; including wsgi stuff like horizon, keystone, etc.
if uses_debs; then
    apache_logs=/var/log/apache2
    if [ -d /etc/apache2/sites-enabled ]; then
        mkdir $LOG_DIR/apache_config
        sudo cp /etc/apache2/sites-enabled/* $LOG_DIR/apache_config
    fi
elif is_fedora; then
    apache_logs=/var/log/httpd
    if [ -d /etc/httpd/conf.d ]; then
        mkdir $LOG_DIR/apache_config
        sudo cp /etc/httpd/conf.d/* $LOG_DIR/apache_config
    fi
fi
if [ -d ${apache_logs} ]; then
    sudo cp -r ${apache_logs} $LOG_DIR/apache
fi

if [ -d /tmp/openstack/tempest ]; then
    sudo cp /tmp/openstack/tempest/etc/tempest.conf $LOG_DIR/
fi

# package status
if [ `command -v dpkg` ]; then
    dpkg -l> $LOG_DIR/dpkg-l.txt
fi
if [ `command -v rpm` ]; then
    rpm -qa > $LOG_DIR/rpm-qa.txt
fi

# system status & informations
df -h > $LOG_DIR/df.txt
free -m > $LOG_DIR/free.txt
cat /proc/cpuinfo > $LOG_DIR/cpuinfo.txt
ps -eo user,pid,ppid,lwp,%cpu,%mem,size,rss,cmd > $LOG_DIR/ps.txt

# Make sure jenkins can read all the logs and configs
sudo chown -R jenkins:jenkins $LOG_DIR/
sudo chmod a+r $LOG_DIR/ $LOG_DIR/etc

# rename files to .txt; this is so that when displayed via
# logs.openstack.org clicking results in the browser shows the
# files, rather than trying to send it to another app or make you
# download it, etc.

# firstly, rename all .log files to .txt files
for f in $(find $LOG_DIR -name "*.log"); do
    sudo mv $f ${f/.log/.txt}
done

# append .txt to all config files
# (there are some /etc/swift .builder and .ring files that get
# caught up which aren't really text, don't worry about that)
find $LOG_DIR/sudoers.d $LOG_DIR/etc -type f -exec mv '{}' '{}'.txt \;

# rabbitmq
if [ -f $LOG_DIR/rabbitmq ]; then
    find $LOG_DIR/rabbitmq -type f -exec mv '{}' '{}'.txt \;
    for X in `find $LOG_DIR/rabbitmq -type f` ; do
        mv "$X" "${X/@/_at_}"
    done
fi


# Compress all text logs
sudo find $LOG_DIR -iname '*.txt' -execdir gzip -9 {} \+
sudo find $LOG_DIR -iname '*.dat' -execdir gzip -9 {} \+
sudo find $LOG_DIR -iname '*.conf' -execdir gzip -9 {} \+
