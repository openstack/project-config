#! /usr/bin/env python

# Copyright 2014 OpenStack Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import json
import requests

done = False
last_change = {}
url = 'https://review.openstack.org/changes/'
params = {'q': '-age:1d', 'o': 'LABELS', 'n': '200'}

# This is what a change looks like
'''
  {
    "kind": "gerritcodereview#change",
    "id": "openstack%2Ftripleo-image-elements~master~"
          "Id520ea27f2803447eff654d14ba8cbb388502a52",
    "project": "openstack/tripleo-image-elements",
    "branch": "master",
    "topic": "bug/1398951",
    "change_id": "Id520ea27f2803447eff654d14ba8cbb388502a52",
    "subject": "Change the kill_metadata executable strings in Neutron",
    "status": "NEW",
    "created": "2014-12-02 23:41:06.000000000",
    "updated": "2014-12-02 23:41:09.698000000",
    "mergeable": false,
    "_sortkey": "003186ad00021d53",
    "_number": 138579,
    "owner": {
      "name": "stephen-ma"
    },
    "labels": {
      "Verified": {
        "recommended": {
          "name": "Jenkins"
        },
        "value": 1
      },
      "Code-Review": {},
      "Workflow": {}
    }
  },
'''

while not done:
    if last_change.get('_sortkey'):
        params['N'] = last_change.get('_sortkey')
    r = requests.get(url, params=params)
    changes = json.loads(r.text[4:])
    for change in changes:
        if (not change.get('labels') or
            not change.get('labels').get('Verified')):
            continue
        for key, value in change['labels']['Verified'].items():
            if key == 'value':
                continue
            if key == 'blocking':
                continue
            if value['name'] == 'Jenkins':
                continue
            print "%s\t%s" % (change['project'], value['name'])
    last_change = change
    done = not last_change.get('_more_changes', False)
