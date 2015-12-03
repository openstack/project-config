#!/bin/bash -e

# Copyright 2013 OpenStack Foundation
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

mkdir -p .test
cd .test

echo "Setting up .test"
if [ -d zuul ]; then
    echo "Updating zuul"
    cd zuul; git pull; cd ..
else
    echo "Cloning zuul"
    git clone https://git.openstack.org/openstack-infra/zuul --depth 1
fi

if [ -d jenkins-job-builder ]; then
    echo "Updating jenkins-job-builder"
    cd jenkins-job-builder; git pull; cd ..
else
    echo "Cloning jenkins-job-builder"
    git clone https://git.openstack.org/openstack-infra/jenkins-job-builder --depth 1
fi

cd jenkins-job-builder
# These are $WORKSPACE/.test/jenkins-job-builder/.test/...
mkdir -p .test/new/config
mkdir -p .test/new/out
cd ../..

cp jenkins/jobs/* .test/jenkins-job-builder/.test/new/config
cd .test/jenkins-job-builder
tox -e compare-xml-new

cd ..
find jenkins-job-builder/.test/new/out/ -printf "%f\n" > job-list.txt

cd zuul
tox -e venv -- zuul-server -c etc/zuul.conf-sample -l ../../zuul/layout.yaml -t ../job-list.txt
