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


def devstack_params(item, job, params):
    change = item.change
    # Note we can't fallback on the default labels because
    # jenkins uses 'devstack-precise || devstack-trusty'.
    # This is necessary to get the gearman plugin to register
    # gearman jobs with both node labels.
    # Remove this when we are done doing prelimindary dib testing.
    if 'icehouse-dibtest' in job.name:
        params['ZUUL_NODE'] = 'devstack-precise-dib'
    elif 'multinode' in job.name and 'dibtest' in job.name:
        params['ZUUL_NODE'] = 'ubuntu-trusty-2-node'
    elif 'dibtest' in job.name:
        params['ZUUL_NODE'] = 'ubuntu-trusty'
    elif ((hasattr(change, 'branch') and
            change.branch == 'stable/icehouse') or
            ('icehouse' in job.name or
             'precise' in job.name)):
        params['ZUUL_NODE'] = 'devstack-precise'
    elif 'centos7' in job.name:
        params['ZUUL_NODE'] = 'devstack-centos7'
    elif 'multinode' in job.name:
        params['ZUUL_NODE'] = 'devstack-trusty-2-node'
    else:
        params['ZUUL_NODE'] = 'devstack-trusty'


def default_params_precise(item, job, params):
    if 'trusty' in job.name:
        params['ZUUL_NODE'] = 'bare-trusty'
    else:
        params['ZUUL_NODE'] = 'bare-precise'


def default_params_trusty(item, job, params):
    change = item.change
    # Note we can't fallback on the default labels because
    # jenkins uses 'bare-precise || bare-trusty'.
    # This is necessary to get the gearman plugin to register
    # gearman jobs with both node labels.
    if ((hasattr(change, 'branch') and
        change.branch == 'stable/icehouse') or
        ('icehouse' in job.name or
        'precise' in job.name)):
        params['ZUUL_NODE'] = 'bare-precise'
    elif job.name == 'bindep-nova-python27':
        params['ZUUL_NODE'] = 'ubuntu-trusty'
    else:
        params['ZUUL_NODE'] = 'bare-trusty'


def set_node_options(item, job, params, default):
    # Set up log url paramter for all jobs
    set_log_url(item, job, params)
    # Default to single use node. Potentially overriden below.
    # Select node to run job on.
    params['OFFLINE_NODE_WHEN_COMPLETE'] = '1'
    proposal_re = r'^.*(merge-release-tags|(propose|upstream)-(.*?)-(constraints-.*|updates?|update-zanata))$'  # noqa
    release_re = r'^.*-(forge|jenkinsci|mavencentral|pypi-(both|wheel))-upload$'
    hook_re = r'^hook-(.*?)-(rtfd)$'
    python26_re = r'^.*-(py(thon)?)?26.*$'
    centos6_re = r'^.*-centos6.*$'
    f21_re = r'^.*-f21.*$'
    tripleo_re = r'^.*-tripleo.*$'
    kolla_image_re = r'^.*-kolla-build-images-.*$'
    openstack_ansible_re = r'^.*-openstack-ansible-.*$'
    devstack_re = r'^.*-dsvm.*$'
    puppetunit_re = (
        r'^gate-(puppet-.*|system-config)-puppet-(lint|syntax|unit).*$')
    # jobs run on the proposal worker
    if (re.match(proposal_re, job.name) or re.match(release_re, job.name) or
            re.match(hook_re, job.name)):
        reusable_node(item, job, params)
    # Jobs needing python26
    elif re.match(python26_re, job.name):
        # Pass because job specified label is always correct.
        pass
    # Kolla build image jobs always have the correct node label.
    # Put before distro specific overrides as they list distros in
    # the jobs names unrelated to where job should run.
    elif re.match(kolla_image_re, job.name):
        pass
    # Jobs needing centos6
    elif re.match(centos6_re, job.name):
        # Pass because job specified label is always correct.
        pass
    # Jobs needing fedora 21
    elif re.match(f21_re, job.name):
        # Pass because job specified label is always correct.
        pass
    # Jobs needing tripleo slaves
    elif re.match(tripleo_re, job.name):
        # Pass because job specified label is always correct.
        pass
    # openstack-ansible jobs
    elif re.match(openstack_ansible_re, job.name):
        # Pass because job specified label is always correct.
        pass
    # Puppet-OpenStack jobs
    elif re.match(puppetunit_re, job.name):
        pass
    # Jobs needing devstack slaves
    elif re.match(devstack_re, job.name):
        devstack_params(item, job, params)
    elif default == 'trusty':
        default_params_trusty(item, job, params)
    else:
        default_params_precise(item, job, params)


def set_node_options_default_precise(item, job, params):
    set_node_options(item, job, params, 'precise')


def set_node_options_default_trusty(item, job, params):
    set_node_options(item, job, params, 'trusty')
