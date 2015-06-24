#!/usr/bin/env python

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
from ZanataUtils import IniConfig, ProjectConfig


def get_args():
    parser = argparse.ArgumentParser(description='Generate a zanata.xml '
                                     'file for this project so we can '
                                     'process translations')
    parser.add_argument('-p', '--project')
    parser.add_argument('-v', '--version')
    parser.add_argument('-s', '--srcdir')
    parser.add_argument('-d', '--txdir')
    parser.add_argument('-r', '--rule', nargs=2, metavar=('PATTERN', 'RULE'),
                        action='append',
                        help='Append a rule, used by the Zanata client to '
                        'match .pot files to translations. Can be specified '
                        'multiple times, and if no rules are specified a '
                        'default will be used.')
    parser.add_argument('-f', '--file', required=True)
    return parser.parse_args()


def main():
    args = get_args()
    zc = IniConfig(os.path.expanduser('~/.config/zanata.ini'))
    rules = args.rule or [('*.pot', '{locale}/LC_MESSAGES/{filename}.po')]
    ProjectConfig(zc, args.file, rules, project=args.project,
                  version=args.version,
                  srcdir=args.srcdir, txdir=args.txdir)


if __name__ == '__main__':
    main()
