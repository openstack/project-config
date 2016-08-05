#!/bin/bash -xe
#
# Copyright 2012 Hewlett-Packard Development Company, L.P.
# Copyright 2013, 2016 OpenStack Foundation
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
#
# Retrieve python tarballs/wheels and make detached OpenPGP signatures.

PROJECT=$1
TARBALL_SITE=$2
TAG=$(echo $ZUUL_REF | sed 's/^refs.tags.//')

# Look in the setup.cfg to determine if a package name is specified, but
# fall back on the project name if necessary. Also look in the setup.cfg
# to see if this is a universal wheel or not
DISTNAME=$(/usr/local/jenkins/slave_scripts/pypi-extract-name.py --wheel \
    || echo $PROJECT)
TARBALL=$(/usr/local/jenkins/slave_scripts/pypi-extract-name.py \
    --tarball || echo $PROJECT)-${TAG}.tar.gz
WHEEL=$(/usr/local/jenkins/slave_scripts/pypi-extract-name.py \
    --wheel || echo $PROJECT)-${TAG}-$( \
    /usr/local/jenkins/slave_scripts/pypi-extract-universal.py || \
    true)-none-any.whl

rm -rf *.asc *.tar.gz *.whl

curl --fail -o $TARBALL https://${TARBALL_SITE}/${PROJECT}/${TARBALL}
file -b $TARBALL | grep gzip # Make sure we actually got a tarball
gpg --armor --detach-sign $TARBALL

# Wheels are not mandatory, so only sign if we have one
if curl --fail -o $WHEEL https://${TARBALL_SITE}/${PROJECT}/${WHEEL}; then
    file -b $WHEEL | grep -i zip # Make sure we actually got a wheel
    gpg --armor --detach-sign $WHEEL
fi
