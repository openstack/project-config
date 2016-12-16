#!/bin/bash
# Copyright (c) 2014 Hewlett-Packard Development Company, L.P.
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
# See the License for the specific language governing permissions and
# limitations under the License.

# To run on Ubuntu 14.04, this depends on:
# diskimage-builder
# qemu-utils
# debootstrap

set -e

## Other options
# export DISTRO=${DISTRO:-centos-minimal}
# export DISTRO=${DISTRO:-fedora-minimal}
export DISTRO=${DISTRO:-ubuntu-minimal}

## Overrite the release
# export DIB_RELEASE=${DIB_RELEASE:-trusty}
# export DIB_RELEASE=${DIB_RELEASE:-25} # fedora

export ELEMENTS_PATH=${ELEMENTS_PATH:-nodepool/elements}
export IMAGE_NAME=${IMAGE_NAME:-devstack-gate}
export NODEPOOL_SCRIPTDIR=${NODEPOOL_SCRIPTDIR:-nodepool/scripts}
export EXTRA_ELEMENTS=${EXTRA_ELEMENTS:-}

## Test your changes to system-config by overriding this; note you can
## get a CONFIG_REF from gerrit should you have uploaded a change
# export CONFIG_SOURCE=${CONFIG_SOURCE:-https://git.openstack.org/openstack-infra/system-config}
# export CONFIG_REF=${CONFIG_REF:-refs/changes/12/123456/1

ZUUL_USER_SSH_PUBLIC_KEY=${ZUUL_USER_SSH_PUBLIC_KEY:-$HOME/.ssh/id_rsa.pub}
if [ ! -f ${ZUUL_USER_SSH_PUBLIC_KEY} ]; then
    echo "Error: There is no SSH public key at: ${ZUUL_USER_SSH_PUBLIC_KEY}"
    echo "Error: Image build will fail. Exiting now."
    exit 1
fi

## If your firewall won't allow outbound DNS connections, you'll want
## to set these to local resolvers
# NODEPOOL_STATIC_NAMESERVER_V4=192.168.0.1
# NODEPOOL_STATIC_NAMESERVER_V6=2000::...

## This will get dib to drop you into a shell on error, useful for debugging
# export break="after-error"

# The list of elements here should match nodepool/nodepool.yaml
disk-image-create -x --no-tmpfs -o $IMAGE_NAME \
    $DISTRO \
    vm \
    simple-init \
    openstack-repos \
    nodepool-base \
    cache-devstack \
    cache-bindep \
    growroot \
    infra-package-needs \
    stackviz \
    $EXTRA_ELEMENTS
