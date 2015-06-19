#!/usr/bin/env python
#
# Check that gerrit/projects.yaml contains valid entries.
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

import argparse
import sys
import yaml


parser = argparse.ArgumentParser()
parser.add_argument('-v', '--verbose',
                    dest='verbose',
                    default=False,
                    action='store_true',
                    )
parser.add_argument(
    'infile',
    help='Path to gerrit/projects.yaml',
)
args = parser.parse_args()

projects = yaml.load(open(args.infile, 'r'))

VALID_LABELS = ["acl-config", "description", "docimpact-group",
                "groups", "homepage", "options", "project",
                "upstream", "upstream-prefix", "use-storyboard"]
VALID_SCHEMES = ['https://', 'http://', 'git://']
DESCRIPTION_REQUIRED = ['openstack', 'openstack-infra', 'openstack-dev',
                        'stackforge']

found_errors = 0
for p in projects:
    name = p.get('project')
    repo_group = name.split('/')[0]
    if not name:
        # not a project
        found_errors += 1
        print("Error: Entry is not a project %s" % p)
        continue
    if args.verbose:
        print('Checking %s' % name)
    description = p.get('description')
    if not description and repo_group in DESCRIPTION_REQUIRED:
        found_errors += 1
        print("Error: Project %s has no description" % name)
        continue
    # Check upstream URL
    # Allow git:// and https:// URLs for importing upstream repositories,
    # but not git@
    upstream = p.get('upstream')
    if upstream:
        for prefix in VALID_SCHEMES:
            if upstream.startswith(prefix):
                break
        else:
            found_errors += 1
            print('Error: Upstream URLs should use a scheme in %s, '
                  'found %s in %s' %
                  (VALID_SCHEMES, p['upstream'], name))
    # Check for any wrong entries
    for entry in p:
        for label in VALID_LABELS:
            if entry == label:
                break
        else:
            found_errors += 1
            print("Error: Unknown keyword '%s' in project %s" % (entry, name))

if found_errors:
    print("Found %d error(s) in %s" % (found_errors, args.infile))
    sys.exit(1)
