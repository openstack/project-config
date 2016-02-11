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

export SUDO='true'
export THIN='true'

STACKVIZ_DIR=/opt/stackviz
cp -r /opt/git/openstack/stackviz $STACKVIZ_DIR

cd $STACKVIZ_DIR

if [ -f /usr/bin/apt-get ] ; then
    sudo apt-get install nodejs npm nodejs-legacy
else
    sudo yum install nodejs npm
fi

sudo npm install -g npm
sudo npm install -g gulp
npm install

gulp prod

rm -rf node_modules/
