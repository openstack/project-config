#!/bin/bash -xe

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

# This script generates a descriptor slug to use with AFS, composed of the
# operating system, its version, and the processor architecture.

# Pull in the os release.
#   ID is 'fedora', 'centos', 'ubuntu'
#   VERSION_ID is '23', '7', '14.04'
#   Nothing else is useful and/or reliable across distros
source /etc/os-release

################################################################################
# Generate an OS Release Name
OS_TYPE=$ID

################################################################################
# Generate a version string.
OS_VERSION=$VERSION_ID
if [ "$OS_TYPE" != "ubuntu" ]; then
    OS_VERSION=$(echo $OS_VERSION | cut -d'.' -f1)
fi

################################################################################
# Get the processor architecture.
#  x86_64, i386, armv7l, armv6l
OS_ARCH=$(uname -m)

################################################################################
# Build the name
AFS_SLUG="$OS_TYPE-$OS_VERSION-$OS_ARCH"
AFS_SLUG=$(echo "$AFS_SLUG" | tr '[:upper:]' '[:lower:]')

export AFS_SLUG
