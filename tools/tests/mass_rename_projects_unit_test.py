#! /usr/bin/env python
#
# Copyright (c) 2015 Hewlett-Packard Development Company, L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import unittest
import sys
import yaml
import six

sys.path.append('tools/')
import mass_rename_projects

class TestMassRenameProjects(unittest.TestCase):

    # Verify the files we're including in this change process
    def test_filesToChange(self):
        gotFilenames = mass_rename_projects.filesToChange.keys()

        expectedFilenames = [
            'gerrit/projects.yaml',
            'gerritbot/channels.yaml',
            'zuul/layout.yaml'
        ]

        six.assertCountEqual(self, gotFilenames, expectedFilenames, "Check that we're modifying the expected files")

    # TODO check projects yaml
    def test_projects_yaml(self):
        renamelist = [
            'glance', # openstack project that doesn't need to be renamed
            'fuel', # fake project but this text exists in places in the projects.yaml file
            'fuel-tasklib', # stackforge project with groups and other nested attributes
            'xstatic-jquery.tablesorter', # stackforge project with acl attribute
            'anvil', # stackforge project, minimal attributes
            'fake-project', # project name doesn't exist
            'anvil-fake' # non-existant project with similar prefix
        ]

        projectYaml = """
- project: stackforge/anvil
  description: A set of python scripts and utilities to forge raw OpenStack into a productive tool!
- project: openstack/glance
  docimpact-group: openstack-manuals
  description: OpenStack Image Management (Glance)
  options:
    - translate
- project: stackforge/fuel-stats
  groups:
    - fuel
  description: Fuel anonymous statistics collector
  docimpact-group: fuel
- project: stackforge/fuel-tasklib
  description: Fuel tasks library.
  docimpact-group: fuel
  groups:
    - fuel
- project: stackforge/xstatic-jquery.tablesorter
  description: Tablesorter jQuery plugin packaged as XStatic.
  acl-config: /home/gerrit2/acls/stackforge/xstatic.config
- project: stackforge/yaql
  description: Yet another query language
        """
        data = yaml.load(projectYaml)

        stacklist = mass_rename_projects.build_list("stackforge", renamelist)

        result = mass_rename_projects.build_project_data(stacklist, data)
        gotData = result.data
        gotGitmoves = result.gitmoves

        # check result
        expectedData = [
            {
                'project': 'openstack/anvil',
                'description': 'A set of python scripts and utilities to forge raw OpenStack into a productive tool!'
            },
            {
                'project': 'openstack/fuel-tasklib',
                'docimpact-group': 'fuel',
                'description': 'Fuel tasks library.',
                'groups': ['fuel']
            },
            {
                'project': 'openstack/glance',
                'docimpact-group': 'openstack-manuals',
                'description': 'OpenStack Image Management (Glance)',
                'options': ['translate']},
            {
                'project': 'stackforge/fuel-stats',
                'docimpact-group': 'fuel',
                'description': 'Fuel anonymous statistics collector',
                'groups': ['fuel']
            },
            {
                'project': 'openstack/xstatic-jquery.tablesorter',
                'acl-config': '/home/gerrit2/acls/openstack/xstatic.config',
                'description': 'Tablesorter jQuery plugin packaged as XStatic.'},
            {
                'project': 'stackforge/yaql',
                'description': 'Yet another query language'
            }
        ]

        six.assertCountEqual(self, gotData, expectedData, "Check results of projects.yaml renames")

        # check gitmoves, should only be stackforge projects
        expectedGitmoves = {
            'gerrit/acls/stackforge/anvil.config'       : 'gerrit/acls/openstack/anvil.config',
            'gerrit/acls/stackforge/xstatic.config'     : 'gerrit/acls/openstack/xstatic.config',
            'gerrit/acls/stackforge/fuel-tasklib.config': 'gerrit/acls/openstack/fuel-tasklib.config'
        }

        six.assertCountEqual(self, gotGitmoves, expectedGitmoves, "Check git command output for projects.yaml renames")

    def test_channels_yaml(self):
        channelsYaml = """
fuel-tracker:
  events:
    - patchset-created
    - change-merged
    - x-vrif-minus-2
  projects:
    - openstack/fuel-plugin-bigswitch
    - openstack/fuel-plugin-block-device
    - openstack/fuel-plugin-openbook
    - openstack/fuel-plugin-purestorage-cinder
    - openstack/fuel-plugin-scaleio
    - openstack/fuel-plugin-wstunnel
    - openstack/fuel-plugin-xenserver
    - openstack/fuel-plugin-zabbix-agents
    - stackforge/fuel-agent
    - stackforge/fuel-astute
    - stackforge/fuel-dev-tools
    - stackforge/fuel-devops
    - stackforge/fuel-docs
    - stackforge/fuel-library
    - stackforge/fuel-main
    - stackforge/fuel-mirror
    - stackforge/fuel-nailgun-agent
    - stackforge/fuel-octane
    - stackforge/fuel-ostf
    - stackforge/fuel-plugin-availability-zones
    - stackforge/fuel-plugin-calamari
    - stackforge/fuel-plugin-calico
    - stackforge/fuel-plugin-ceilometer-redis
    - stackforge/fuel-plugin-cinder-netapp
    - stackforge/fuel-plugin-cisco-aci
    - stackforge/fuel-plugin-contrail
    - stackforge/fuel-plugin-dbaas-trove
    - stackforge/fuel-plugin-detach-database
    - stackforge/fuel-plugin-detach-keystone
    - stackforge/fuel-plugin-detach-rabbitmq
    - stackforge/fuel-plugin-elasticsearch-kibana
    - stackforge/fuel-plugin-external-emc
    - stackforge/fuel-plugin-external-glusterfs
    - stackforge/fuel-plugin-external-zabbix
    - stackforge/fuel-plugin-glance-nfs
    - stackforge/fuel-plugin-ha-fencing
    - stackforge/fuel-plugin-influxdb-grafana
    - stackforge/fuel-plugin-ironic
    - stackforge/fuel-plugin-ldap
    - stackforge/fuel-plugin-lma-collector
    - stackforge/fuel-plugin-lma-infrastructure-alerting
    - stackforge/fuel-plugin-mellanox
    - stackforge/fuel-plugin-midonet
    - stackforge/fuel-plugin-neutron-fwaas
    - stackforge/fuel-plugin-neutron-lbaas
    - stackforge/fuel-plugin-neutron-vpnaas
    - stackforge/fuel-plugin-nova-nfs
    - stackforge/fuel-plugin-nsxv
    - stackforge/fuel-plugin-opendaylight
    - stackforge/fuel-plugin-saltstack
    - stackforge/fuel-plugin-solidfire-cinder
    - stackforge/fuel-plugin-swiftstack
    - stackforge/fuel-plugin-tintri-cinder
    - stackforge/fuel-plugin-tls
    - stackforge/fuel-plugin-vmware-dvs
    - stackforge/fuel-plugin-vxlan
    - stackforge/fuel-plugin-zabbix-monitoring-emc
    - stackforge/fuel-plugin-zabbix-monitoring-extreme-networks
    - stackforge/fuel-plugin-zabbix-snmptrapd
    - stackforge/fuel-plugins
    - stackforge/fuel-provision
    - stackforge/fuel-qa
    - stackforge/fuel-specs
    - stackforge/fuel-stats
    - stackforge/fuel-tasklib
    - stackforge/fuel-upgrade
    - stackforge/fuel-web
    - stackforge/python-fuelclient
  branches:
    - master
openstack-anvil:
  events:
    - patchset-created
    - change-merged
    - x-vrif-minus-2
  projects:
    - stackforge/anvil
  branches:
    - master
openstack-glance:
  events:
    - patchset-created
    - change-merged
    - x-vrif-minus-2
  projects:
    - openstack/glance
    - openstack/glance-specs
    - openstack/glance_store
    - openstack/python-glanceclient
  branches:
    - master
openstack-horizon:
  events:
    - patchset-created
    - change-merged
    - x-vrif-minus-2
  projects:
    - openstack/django-openstack-auth-kerberos
    - openstack/django_openstack_auth
    - openstack/horizon
    - openstack/manila-ui
    - openstack/tuskar-ui
    - stackforge/xstatic-angular
    - stackforge/xstatic-angular-animate
    - stackforge/xstatic-angular-bootstrap
    - stackforge/xstatic-angular-cookies
    - stackforge/xstatic-angular-fileupload
    - stackforge/xstatic-angular-lrdragndrop
    - stackforge/xstatic-angular-mock
    - stackforge/xstatic-angular-sanitize
    - stackforge/xstatic-angular-smart-table
    - stackforge/xstatic-bootstrap-datepicker
    - stackforge/xstatic-bootstrap-scss
    - stackforge/xstatic-d3
    - stackforge/xstatic-font-awesome
    - stackforge/xstatic-hogan
    - stackforge/xstatic-jasmine
    - stackforge/xstatic-jquery-migrate
    - stackforge/xstatic-jquery.bootstrap.wizard
    - stackforge/xstatic-jquery.quicksearch
    - stackforge/xstatic-jquery.tablesorter
    - stackforge/xstatic-jsencrypt
    - stackforge/xstatic-magic-search
    - stackforge/xstatic-qunit
    - stackforge/xstatic-rickshaw
    - stackforge/xstatic-spin
  branches:
    - master
        """

        renamelist = [
            'glance', # openstack project that doesn't need to be renamed
            'fuel', # fake project but this text exists in places in the projects.yaml file
            'fuel-tasklib', # stackforge project with groups and other nested attributes
            'xstatic-jquery.tablesorter', # stackforge project with acl attribute
            'anvil', # stackforge project, minimal attributes
            'fake-project', # project name doesn't exist
            'anvil-fake' # non-existant project with similar prefix
        ]

        data = yaml.load(channelsYaml)

        stacklist = mass_rename_projects.build_list("stackforge", renamelist)

        gotData = mass_rename_projects.build_channel_data(stacklist, data)

        # check result
        expectedData = {
    'fuel-tracker': {
        'branches': [
            'master'
        ],
        'events': [
            'patchset-created',
            'change-merged',
            'x-vrif-minus-2'
        ],
        'projects': [
            'openstack/fuel-plugin-bigswitch',
            'openstack/fuel-plugin-block-device',
            'openstack/fuel-plugin-openbook',
            'openstack/fuel-plugin-purestorage-cinder',
            'openstack/fuel-plugin-scaleio',
            'openstack/fuel-plugin-wstunnel',
            'openstack/fuel-plugin-xenserver',
            'openstack/fuel-plugin-zabbix-agents',
            'openstack/fuel-tasklib',
            'stackforge/fuel-agent',
            'stackforge/fuel-astute',
            'stackforge/fuel-dev-tools',
            'stackforge/fuel-devops',
            'stackforge/fuel-docs',
            'stackforge/fuel-library',
            'stackforge/fuel-main',
            'stackforge/fuel-mirror',
            'stackforge/fuel-nailgun-agent',
            'stackforge/fuel-octane',
            'stackforge/fuel-ostf',
            'stackforge/fuel-plugin-availability-zones',
            'stackforge/fuel-plugin-calamari',
            'stackforge/fuel-plugin-calico',
            'stackforge/fuel-plugin-ceilometer-redis',
            'stackforge/fuel-plugin-cinder-netapp',
            'stackforge/fuel-plugin-cisco-aci',
            'stackforge/fuel-plugin-contrail',
            'stackforge/fuel-plugin-dbaas-trove',
            'stackforge/fuel-plugin-detach-database',
            'stackforge/fuel-plugin-detach-keystone',
            'stackforge/fuel-plugin-detach-rabbitmq',
            'stackforge/fuel-plugin-elasticsearch-kibana',
            'stackforge/fuel-plugin-external-emc',
            'stackforge/fuel-plugin-external-glusterfs',
            'stackforge/fuel-plugin-external-zabbix',
            'stackforge/fuel-plugin-glance-nfs',
            'stackforge/fuel-plugin-ha-fencing',
            'stackforge/fuel-plugin-influxdb-grafana',
            'stackforge/fuel-plugin-ironic',
            'stackforge/fuel-plugin-ldap',
            'stackforge/fuel-plugin-lma-collector',
            'stackforge/fuel-plugin-lma-infrastructure-alerting',
            'stackforge/fuel-plugin-mellanox',
            'stackforge/fuel-plugin-midonet',
            'stackforge/fuel-plugin-neutron-fwaas',
            'stackforge/fuel-plugin-neutron-lbaas',
            'stackforge/fuel-plugin-neutron-vpnaas',
            'stackforge/fuel-plugin-nova-nfs',
            'stackforge/fuel-plugin-nsxv',
            'stackforge/fuel-plugin-opendaylight',
            'stackforge/fuel-plugin-saltstack',
            'stackforge/fuel-plugin-solidfire-cinder',
            'stackforge/fuel-plugin-swiftstack',
            'stackforge/fuel-plugin-tintri-cinder',
            'stackforge/fuel-plugin-tls',
            'stackforge/fuel-plugin-vmware-dvs',
            'stackforge/fuel-plugin-vxlan',
            'stackforge/fuel-plugin-zabbix-monitoring-emc',
            'stackforge/fuel-plugin-zabbix-monitoring-extreme-networks',
            'stackforge/fuel-plugin-zabbix-snmptrapd',
            'stackforge/fuel-plugins',
            'stackforge/fuel-provision',
            'stackforge/fuel-qa',
            'stackforge/fuel-specs',
            'stackforge/fuel-stats',
            'stackforge/fuel-upgrade',
            'stackforge/fuel-web',
            'stackforge/python-fuelclient'
        ]
    },
    'openstack-glance': {
        'branches': [
            'master'
        ],
        'events': [
            'patchset-created',
            'change-merged',
            'x-vrif-minus-2'
        ],
        'projects': [
            'openstack/glance',
            'openstack/glance-specs',
            'openstack/glance_store',
            'openstack/python-glanceclient'
        ]
    },
    'openstack-anvil': {
        'branches': [
            'master'
        ],
        'events': [
            'patchset-created',
            'change-merged',
            'x-vrif-minus-2'
        ],
        'projects': [
            'openstack/anvil'
        ]
    },
    'openstack-horizon': {
        'branches': [
            'master'
        ],
        'events': [
            'patchset-created',
            'change-merged',
            'x-vrif-minus-2'
        ],
        'projects': [
            'openstack/django-openstack-auth-kerberos',
            'openstack/django_openstack_auth',
            'openstack/horizon',
            'openstack/manila-ui',
            'openstack/tuskar-ui',
            'openstack/xstatic-jquery.tablesorter',
            'stackforge/xstatic-angular',
            'stackforge/xstatic-angular-animate',
            'stackforge/xstatic-angular-bootstrap',
            'stackforge/xstatic-angular-cookies',
            'stackforge/xstatic-angular-fileupload',
            'stackforge/xstatic-angular-lrdragndrop',
            'stackforge/xstatic-angular-mock',
            'stackforge/xstatic-angular-sanitize',
            'stackforge/xstatic-angular-smart-table',
            'stackforge/xstatic-bootstrap-datepicker',
            'stackforge/xstatic-bootstrap-scss',
            'stackforge/xstatic-d3',
            'stackforge/xstatic-font-awesome',
            'stackforge/xstatic-hogan',
            'stackforge/xstatic-jasmine',
            'stackforge/xstatic-jquery-migrate',
            'stackforge/xstatic-jquery.bootstrap.wizard',
            'stackforge/xstatic-jquery.quicksearch',
            'stackforge/xstatic-jsencrypt',
            'stackforge/xstatic-magic-search',
            'stackforge/xstatic-qunit',
            'stackforge/xstatic-rickshaw',
            'stackforge/xstatic-spin'
        ]
    }
}
        six.assertCountEqual(self, gotData, expectedData, "Check result for channels.yaml renames")

    # TODO check zuul layout
    def test_zuul_layout(self):
        renamelist = [
            'glance', # openstack project that doesn't need to be renamed
            'fuel', # fake project but this text exists in places in the projects.yaml file
            'fuel-tasklib', # stackforge project with groups and other nested attributes
            'xstatic-jquery.tablesorter', # stackforge project with acl attribute
            'anvil', # stackforge project, minimal attributes
            'fake-project', # project name doesn't exist
            'anvil-fake' # non-existant project with similar prefix
        ]

        # not currently needed because the actual script shells out to sed
        layoutYaml = """
        """

        openlist = mass_rename_projects.build_list('openstack', renamelist) # zuul layout just uses the openlist as its data

        expectedOpenlist = [
            'openstack/glance',
            'openstack/fuel',
            'openstack/fuel-tasklib',
            'openstack/xstatic-jquery.tablesorter',
            'openstack/anvil',
            'openstack/fake-project',
            'openstack/anvil-fake'
        ]

        six.assertCountEqual(self, openlist, expectedOpenlist, "Check zuul layout data")


if __name__ == '__main__':
    unittest.main(verbosity=2)
