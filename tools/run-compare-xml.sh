#!/bin/bash -e

# Copyright (c) 2012, AT&T Labs, Yun Mao <yunmao@gmail.com>
# All Rights Reserved.
# Copyright 2012 Hewlett-Packard Development Company, L.P.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

rm -fr .test
mkdir .test
cd .test
/usr/zuul-env/bin/zuul-cloner -m ../tools/run-compare-clonemap.yaml --cache-dir /opt/git git://git.openstack.org openstack-infra/jenkins-job-builder
cd jenkins-job-builder
# These are $WORKSPACE/.test/jenkins-job-builder/.test/...
mkdir -p .test/old/config
mkdir -p .test/old/out
mkdir -p .test/new/config
mkdir -p .test/new/out
cd ../..

GITHEAD=`git rev-parse HEAD`

# First generate output from HEAD~1
git checkout HEAD~1
cp jenkins/jobs/* .test/jenkins-job-builder/.test/old/config

# Then use that as a reference to compare against HEAD
git checkout $GITHEAD
cp jenkins/jobs/* .test/jenkins-job-builder/.test/new/config

cd .test/jenkins-job-builder

tox -e compare-xml-old
tox -e compare-xml-new

diff -r -N -u .test/old/out .test/new/out
CHANGED=$?  # 0 == same ; 1 == different ; 2 == error

echo
echo "You are in detached HEAD mode. If you are a developer"
echo "and not very familiar with git, you might want to do"
echo "'git checkout branch-name' to go back to your branch."

exit $CHANGED
