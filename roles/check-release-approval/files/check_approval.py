#!/usr/bin/env python3
#
# Check PTL/liaison has approved release
#
# Copyright 2019 Thierry Carrez <thierry@openstack.org>
# All Rights Reserved.
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

import argparse
import json
import logging
import os
import sys

import requests
from requests.packages import urllib3
import yaml


PROJECTS_YAML = 'reference/projects.yaml'
GERRIT_URL = 'https://review.opendev.org/'
LOG = logging.getLogger(__name__)

# Turn of warnings about bad SSL config.
# https://urllib3.readthedocs.io/en/latest/advanced-usage.html#ssl-warnings
urllib3.disable_warnings()


def get_team(workspace, deliverablefile):
    with open(os.path.join(workspace, deliverablefile), 'r') as dfile:
        team = yaml.safe_load(dfile)['team']
    return team


def get_liaisons(workspace, team):
    filename = os.path.join(workspace, 'data/release_liaisons.yaml')
    with open(filename, 'r') as lfile:
        liaisons = yaml.safe_load(lfile)
    if team in liaisons:
        return [i['email'] for i in liaisons[team]]
    else:
        print('WARNING: %s team does not exist in liaisons file' % team)
        return []


class GerritChange(object):

    def __init__(self, args):
        # Load governance data
        with open(os.path.join(args.governance, PROJECTS_YAML), 'r') as dfile:
            self.gov_data = yaml.safe_load(dfile)

        self.load_from_gerrit(args.changeid)
        self.workspace = args.releases

    def load_from_gerrit(self, changeid):
        # Grab changeid details from Gerrit
        call = 'changes/%s' % changeid + \
               '?o=CURRENT_REVISION&o=CURRENT_FILES&o=DETAILED_LABELS' + \
               '&o=DETAILED_ACCOUNTS'
        raw = requests.get(GERRIT_URL + call)

        # Gerrit's REST API prepends a JSON-breaker to avoid XSS
        if raw.text.startswith(")]}'"):
            trimmed = raw.text[4:]
        else:
            trimmed = raw.text

        # Try to decode and bail with much detail if it fails
        try:
            decoded = json.loads(trimmed)
        except Exception:
            LOG.error(
                '\nrequest returned %s error to query:\n\n    %s\n'
                '\nwith detail:\n\n    %s\n',
                raw, raw.url, trimmed)
            raise

        # Extract approvers from JSON data. Approvers include last committer
        # and anyone who voted Code-Review+1. NB: Gerrit does not fill
        # labels.CodeReview.all unless there is a vote already
        last_revision = decoded['revisions'][decoded['current_revision']]
        self.approvers = [last_revision['uploader']['email']]
        if 'all' in decoded['labels']['Code-Review']:
            self.approvers.extend([
                i['email']
                for i in decoded['labels']['Code-Review']['all']
                if i['value'] > 0
            ])

        # Extract list of modified deliverables files from JSON data
        currev = decoded['current_revision']
        self.deliv_files = [
            x for x in decoded['revisions'][currev]['files'].keys()
            if x.startswith('deliverables/')
        ]

    def is_approved(self):
        LOG.debug('Approvals: %s' % self.approvers)
        approved = True
        for deliv_file in self.deliv_files:
            team = get_team(self.workspace, deliv_file)
            try:
                govteam = self.gov_data[team]
            except ValueError:
                print('✕ %s mentions unknown team %s' % (deliv_file, team))
                approved = False
                break

            # Check that deliverable is indeed defined in governance team
            delivname, _ = os.path.splitext(os.path.basename(deliv_file))
            if delivname not in govteam['deliverables']:
                print('✕ %s not in %s governance' % (deliv_file, team))
                approved = False
                break

            # Fetch release liaisons from data/release_liaisons.yaml
            liaisons = get_liaisons(self.workspace, team)

            # Some teams follow the "distributed project lead" governance
            # model so they are PTL-less but they have release liaisons
            # defined. Fetch those liaisons.
            if govteam.get('leadership_type') == 'distributed':
                distributed_release_liaisons = govteam['liaisons']['release']
                for liaison in distributed_release_liaisons:
                    liaisons.append(liaison['email'])

            # Fetch PTL's email address (note: some teams may be PTL-less,
            # so don't assume we have PTL info)
            if 'email' in govteam.get('ptl', {}):
                liaisons.append(govteam['ptl']['email'])
            LOG.debug('%s needs %s' % (deliv_file, liaisons))

            for approver in self.approvers:
                if approver in liaisons:
                    print('✓ %s validated by %s' % (deliv_file, approver))
                    break
            else:
                print('✕ %s missing PTL/liaison approval' % deliv_file)
                approved = False
        return approved


def main(args=sys.argv[1:]):
    parser = argparse.ArgumentParser()
    parser.add_argument('changeid')
    parser.add_argument('releases')
    parser.add_argument('governance')
    parser.add_argument("--debug", action='store_true')
    args = parser.parse_args(args)

    if (args.debug):
        logging.basicConfig(level=logging.DEBUG)

    change = GerritChange(args)

    if not change.is_approved():
        sys.exit(1)


if __name__ == '__main__':
    main()
