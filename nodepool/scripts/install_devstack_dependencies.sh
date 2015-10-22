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

mkdir -p ~/cache/files
mkdir -p ~/cache/pip

if [ -f /usr/bin/yum ]; then
    sudo yum -y install python-devel python3-devel make automake gcc gcc-c++ \
        kernel-devel redhat-lsb-core
elif [ -f /usr/bin/apt-get ]; then
    if [ "$(lsb_release -c -s)" = "precise" ]; then
        # temporary - remove the breaking -70 kernel and
        # reinstall -69 to prevent openvswitch breakage
        sudo DEBIAN_FRONTEND=noninteractive apt-get \
            --option "Dpkg::Options::=--force-confold" \
            --assume-yes remove linux-headers-3.2.0-70 \
            linux-headers-3.2.0-70-virtual \
            linux-image-3.2.0-70-virtual \
            linux-headers-3.2.0-70-generic \
            linux-image-3.2.0-70-generic
        sudo DEBIAN_FRONTEND=noninteractive apt-get \
            --option "Dpkg::Options::=--force-confold" \
            --assume-yes install --reinstall linux-headers-3.2.0-69 \
            linux-headers-3.2.0-69-virtual \
            linux-image-3.2.0-69-virtual \
            python-software-properties build-essential python-dev python3-dev
    else
        sudo DEBIAN_FRONTEND=noninteractive apt-get \
            --option "Dpkg::Options::=--force-confold" \
            --assume-yes install build-essential python-dev python3-dev \
            python-software-properties linux-headers-virtual linux-headers-$(uname -r)
    fi
else
    echo "Unsupported distro."
    exit 1
fi
