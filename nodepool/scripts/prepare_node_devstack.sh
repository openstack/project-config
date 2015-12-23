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
TEMPEST_DIR=${TEMPEST_DIR:-/opt/git/openstack/tempest}

./prepare_node.sh "$HOSTNAME"
sudo -u jenkins -i /opt/nodepool-scripts/prepare_devstack.sh "$HOSTNAME"

# Setup venv and install deps for prepare_tempest_testrepository.py
sudo virtualenv -p python2 /opt/git/subunit2sql-env
sudo -H /opt/git/subunit2sql-env/bin/pip install -U testrepository \
    subunit2sql PyMySQL

# Pre-seed tempest testrepository with data from subunit2sql
sudo -i env PATH=/opt/git/subunit2sql-env/bin:$PATH \
    /opt/git/subunit2sql-env/bin/python2 \
    /opt/nodepool-scripts/prepare_tempest_testrepository.py \
    $TEMPEST_DIR

sudo chown -R jenkins:jenkins $TEMPEST_DIR/preseed-streams

# Delete the venv after the script is called
sudo rm -rf /opt/git/subunit2sql-env

./restrict_memory.sh
