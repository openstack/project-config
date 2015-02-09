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

from oslo.db.sqlalchemy import utils as db_utils
from subunit2sql.db import api
from subunit2sql.db import models
from subunit2sql import shell
from subunit2sql import write_subunit


DB_URI = 'mysql+pymysql://query:query@logstash.openstack.org/subunit2sql'

if len(sys.argv) == 2:
    TEMPEST_PATH = sys.argv[1]
elif len(sys.argv) > 2:
    TEMPEST_PATH = sys.argv[1]
    DB_URI = sys.argv[2]
else:
    TEMPEST_PATH = '/opt/stack/new/tempest'


def get_run_ids(session):
    # TODO(mtreinish): Move this function into the subunit2sql db api
    results = db_utils.model_query(models.Run, session).order_by(
        models.Run.run_at.desc()).filter_by(fails=0).limit(10).all()
    return map(lambda x: x.id, results)


def main():
    shell.parse_args([])
    shell.CONF.set_override('connection', DB_URI, group='database')
    session = api.get_session()
    run_ids = get_run_ids(session)
    session.close()
    preseed_path = os.path.join(TEMPEST_PATH, 'preseed-streams')
    os.mkdir(preseed_path)
    for run in run_ids:
        with open(os.path.join(preseed_path, run + '.subunit'), 'w') as fd:
            write_subunit.sql2subunit(run, fd)

if __name__ == '__main__':
    main()
