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

NODEPOOL_PYPI_MIRROR=${NODEPOOL_PYPI_MIRROR:-http://pypi.$NODEPOOL_REGION.openstack.org/simple}

sudo sed -i -e "s,^index-url = .*,index-url = $NODEPOOL_PYPI_MIRROR," \
    /etc/pip.conf

cat >/home/jenkins/.pydistutils.cfg <<EOF
[easy_install]
index_url = $NODEPOOL_PYPI_MIRROR
allow_hosts = *.openstack.org
EOF

# Double check that when the node is made ready it is able
# to resolve names against DNS.
host git.openstack.org
host pypi.${NODEPOOL_REGION}.openstack.org

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
