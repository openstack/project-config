#!/usr/bin/env python

# Copyright (c) 2015 Hewlett-Packard Development Company, L.P.
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

import argparse
import os
import json
import sys
from ZanataUtils import IniConfig, ZanataRestService


def get_args():
    parser = argparse.ArgumentParser(description='Check if a version for the '
                                     'specificed project exists on the Zanata '
                                     'server')
    parser.add_argument('-p', '--project', required=True)
    parser.add_argument('-v', '--version', required=True)
    parser.add_argument('--no-verify', action='store_false', dest='verify',
                        help='Do not perform HTTPS certificate verification')
    return parser.parse_args()


def main():
    args = get_args()
    zc = IniConfig(os.path.expanduser('~/.config/zanata.ini'))
    rest_service = ZanataRestService(zc, content_type='application/json',
                                     verify=args.verify)
    try:
        r = rest_service.query(
            '/rest/projects/p/%s/iterations/i/%s'
            % (args.project, args.version))
    except ValueError:
        sys.exit(1)
    if r.status_code == 200:
        details = json.loads(r.content)
        if details['status'] == 'READONLY':
            sys.exit(1)
        sys.exit(0)


if __name__ == '__main__':
    main()
