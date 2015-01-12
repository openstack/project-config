#!/usr/bin/env python2
#
# Copyright 2014 Hewlett-Packard Development Company, L.P.
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

import os
import sys
import tempfile

from subunit2sql import shell
from subunit2sql import write_subunit

from common import run_local


DB_URI = 'mysql+pymysql://query:query@logstash.openstack.org/subunit2sql'

if len(sys.argv) == 2:
    TEMPEST_PATH = sys.argv[1]
elif len(sys.argv) > 2:
    TEMPEST_PATH = sys.argv[1]
    DB_URI = sys.argv[2]
else:
    TEMPEST_PATH = '/opt/stack/new/tempest'


def init_testr():
    if not os.path.isdir(os.path.join(TEMPEST_PATH, '.testrepository')):
        (status, out) = run_local(['testr', 'init'], status=True,
                                  cwd=TEMPEST_PATH)
        if status != 0:
            print("testr init failed with:\n%s' % out")
            exit(status)


def generate_subunit_stream(fd):
    write_subunit.avg_sql2subunit(output=fd)


def populate_testrepository(path):
    run_local(['testr', 'load', path], cwd=TEMPEST_PATH)


def main():
    init_testr()
    shell.parse_args([])
    shell.CONF.set_override('connection', DB_URI, group='database')
    with tempfile.NamedTemporaryFile() as fd:
        generate_subunit_stream(fd)
        populate_testrepository(fd.name)


if __name__ == '__main__':
    main()
