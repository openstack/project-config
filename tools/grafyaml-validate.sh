#!/bin/bash -e

# Copyright 2016 IBM Corp.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

ROOT=`pwd`
if [ -z $VIRTUAL_ENV ]; then
    echo "VIRTUAL_ENV environment variable not found"
    echo "Run this script with 'tox -e grafyaml' and with recent versions"
    echo "of tox and virtualenv installed."
    exit 1
fi

cd $VIRTUAL_ENV
if [ ! -e /usr/zuul-env/bin/zuul-cloner ] &&
    [ ! -e $VIRTUAL_ENV/bin/zuul-cloner ];
then
    echo "Need to install zuul-cloner"
    git clone https://git.openstack.org/openstack-infra/zuul
    cd zuul
    pip install .
    cd ..
fi

if [ -e /usr/zuul-env/bin/zuul-cloner ]; then
    ZC=/usr/zuul-env/bin/zuul-cloner
else
    ZC=$VIRTUAL_ENV/bin/zuul-cloner
fi
echo "Zuul-cloner is $ZC"

$ZC --cache-dir /opt/git https://git.openstack.org openstack-infra/grafyaml
cd openstack-infra/grafyaml
pip install .
cd ../..

cd $ROOT
grafana-dashboard validate grafana
