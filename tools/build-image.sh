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

#
# Read through this script.  There are a lot of comments that might
# help you!
#

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

ZUUL_USER_SSH_PUBLIC_KEY=${ZUUL_USER_SSH_PUBLIC_KEY:-$HOME/.ssh/id_rsa.pub}
if [ ! -f ${ZUUL_USER_SSH_PUBLIC_KEY} ]; then
    echo "Error: There is no SSH public key at: ${ZUUL_USER_SSH_PUBLIC_KEY}"
    echo "Error: Image build will fail. Exiting now."
    exit 1
fi

## Several parts of infra node bringup require EPEL, but we don't want
## to introduce dependencies on it, so keep disabled.
if [[ ${DISTRO} == "centos-minimal" ]]; then
    EXTRA_ELEMENTS+="epel "
    export DIB_EPEL_DISABLED=1
fi


## If your firewall won't allow outbound DNS connections, you'll want
## to set these to local resolvers
# export NODEPOOL_STATIC_NAMESERVER_V4=192.168.0.1
# export NODEPOOL_STATIC_NAMESERVER_V6=2000::...

## This will get dib to drop you into a shell on error, useful for debugging
# export break="after-error"

## If you need to debug the boot, setting this longer might help you
## break into the grub console.  Or set it to 0 for fast boot.
# export DIB_GRUB_TIMEOUT=10

## The openstack-repos element caches every git repo, wihch can take
## quite some time.  We can override this, but some minimal repos are
## required for a successful build.  For speeding up builds when
## you're testing the following should work, but be very careful
## stripping things out when generating real images.

## add to /tmp/custom_projects.yaml:
##
## - project: openstack-infra/project-config
## - project: openstack-infra/system-config
## - project: openstack-dev/devstack
## - project: openstack/tempest

# export DIB_CUSTOM_PROJECTS_LIST_URL='file:///tmp/custom_projects.yaml'

## If you are building test images, or dealing with networking issues,
## you will want to have a local login with password available (as
## opposed to key-based ssh only).  You can use the "devuser" element
## from dib to set this up.  Don't forget to enable sudo and set the
## password.

## defaults
## export DIB_DEV_USER_USERNAME=devuser
## export DIB_DEV_USER_AUTHORIZED_KEYS=$HOME/.ssh/id_rsa.pub

# EXTRA_ELEMENTS+=devuser
# export DIB_DEV_USER_PWDLESS_SUDO=1
# export DIB_DEV_USER_PASSWORD=devuser

## The list of elements below should match those configured
## in nodepool/nodepool.yaml

disk-image-create -x --no-tmpfs -o $IMAGE_NAME \
    $DISTRO \
    vm \
    simple-init \
    openstack-repos \
    nodepool-base \
    cache-devstack \
    growroot \
    infra-package-needs \
    stackviz \
    $EXTRA_ELEMENTS
