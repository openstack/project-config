#!/bin/bash -xe
#
# Copyright 2015 Hewlett-Packard Development Company, L.P.
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
# Retrieve a javascript sdist and upload it to npm.

PROJECT=$1
TARBALL_SITE=$2
TAG=$(echo $ZUUL_REF | sed 's/^refs.tags.//')

# Build the filename from the discovered tag and projectname.
FILENAME="$PROJECT-$TAG.tgz"

rm -rf *tgz
curl --fail -o $FILENAME http://$TARBALL_SITE/$PROJECT/$FILENAME

# Make sure we actually got a gzipped file
file -b $FILENAME | grep gzip

# Perform an NPM publish of the provided package, without executing any
# lifecycle scripts.
npm publish --ignore-scripts $FILENAME
