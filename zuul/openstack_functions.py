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

import re


def set_log_url(item, job, params):
    if hasattr(item.change, 'refspec'):
        path = "%s/%s/%s/%s/" % (
            params['ZUUL_CHANGE'][-2:], params['ZUUL_CHANGE'],
            params['ZUUL_PATCHSET'], params['ZUUL_PIPELINE'])
    elif hasattr(item.change, 'ref'):
        path = "%s/%s/%s/" % (
            params['ZUUL_NEWREV'][:2], params['ZUUL_NEWREV'],
            params['ZUUL_PIPELINE'])
    else:
        path = params['ZUUL_PIPELINE'] + '/'
    params['BASE_LOG_PATH'] = path
    params['LOG_PATH'] = path + '%s/%s/' % (job.name,
                                            params['ZUUL_UUID'][:7])


def reusable_node(item, job, params):
    if 'OFFLINE_NODE_WHEN_COMPLETE' in params:
        del params['OFFLINE_NODE_WHEN_COMPLETE']


def set_node_options(item, job, params):
    # Force tox to pass through ZUUL_ variables
    zuul_params = [x for x in params.keys() if x.startswith('ZUUL_')]
    params['TOX_TESTENV_PASSENV'] = ' '.join(zuul_params)
    # Set up log url parameter for all jobs
    set_log_url(item, job, params)
    # Default to single use node. Potentially overridden below.
    # Select node to run job on.
    params['OFFLINE_NODE_WHEN_COMPLETE'] = '1'
    # Pass tags through for subunit2sql
    params['JOB_TAGS'] = ' '.join(sorted(job.tags))
    proposal_re = r'^.*(propose|upstream)-(.*?)-(constraints-.*|updates?|update-(liberty|mitaka|newton|ocata|pike)|plugins-list|openstack-constraints|update-constraints|osa-test-files)$'  # noqa
    release_re = r'^.*-(forge|jenkinsci|mavencentral|pypi-(both|wheel)|npm)-upload$'
    hook_re = r'^hook-(.*?)-(rtfd)$'
    wheel_re = r'^wheel-(build|release)-.*$'
    reprepro_re = r'^reprepro-(import|release|sign)-.*$'
    signing_re = r'^(.*-tarball-signing|tag-releases)$'
    # jobs run on the persistent proposal, release, signing, and wheel
    # build workers
    if (re.match(proposal_re, job.name) or
        re.match(release_re, job.name) or
        re.match(hook_re, job.name) or
        re.match(reprepro_re, job.name) or
        re.match(signing_re, job.name) or
        re.match(wheel_re, job.name)):
        reusable_node(item, job, params)
