#!/bin/bash -xe
#
# Copyright (C) 2016 Red Hat, Inc.
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
# Get latest RDO trunk consistent URL
#

DIR='puppet-openstack-integration'
BASE_URL=https://trunk.rdoproject.org/centos7-master
CONSISTENT_URL=$BASE_URL/consistent/versions.csv

ts=0
for current in $(curl -s $CONSISTENT_URL); do
    val=$(echo $current|cut -d, -f7)
    if [[ "$val" != 'Last Success Timestamp' ]] && [[ "$val" -gt "$ts" ]]; then
        ts=$val
        line=$current
    fi
done

if [ $ts = 0 ]; then
    echo "something went wrong aborting" 1>&2
    exit 1
fi

sha1=$(echo $line|cut -d, -f3)
psha1=$(echo $line|cut -d, -f5|sed 's/\(........\).*/\1/')
url=$BASE_URL/$(echo $sha1|sed 's/\(..\).*/\1/')/$(echo $sha1|sed 's/..\(..\).*/\1/')/${sha1}_${psha1}/
sed -i "s@\(.* => \)'http.*\(centos7\|delorean\).*',@\1'$url',@" $DIR/manifests/repos.pp

# for debug
cat $DIR/manifests/repos.pp
