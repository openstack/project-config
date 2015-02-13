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

sudo sed -i -e "s,^index-url = .*,index-url = $NODEPOOL_PYPI_MIRROR," /etc/pip.conf

cat >/home/jenkins/.pydistutils.cfg <<EOF
[easy_install]
index_url = $NODEPOOL_PYPI_MIRROR
EOF

# Double check that when the node is made ready it is able
# to resolve names against DNS.
host git.openstack.org
host pypi.${NODEPOOL_REGION}.openstack.org
