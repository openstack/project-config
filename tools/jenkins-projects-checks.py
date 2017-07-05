#! /usr/bin/env python

# Copyright 2014 SUSE Linux Products GmbH
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

import copy
import io
import glob
import sys
import requests
import voluptuous as v

# The files uses YAML extensions like !include, therefore use the
# jenkins-job-builder yaml parser for loading.
from jenkins_jobs import local_yaml


BUILDER = v.Schema({
    v.Required('name'): v.All(str),
    v.Required('builders'): v.All(list),
    'description': v.All(str)
}, extra=True)

JOB = v.Schema({
    v.Required('builders'): v.All(list),
    v.Required('name'): v.All(str),
    v.Required('node'): v.All(str),
    v.Required('publishers'): v.All(list),
    'description': v.All(str),
    'parameters': v.All(list),
    'wrappers': v.All(list)
})

JOB_GROUP = v.Schema({
    v.Required('name'): v.All(str),
    v.Required('jobs'): v.All(list),
    'description': v.All(str)
}, extra=True)

JOB_TEMPLATE = v.Schema({
    v.Required('builders'): v.All(list),
    v.Required('name'): v.All(str),
    v.Required('node'): v.All(str),
    v.Required('publishers'): v.All(list),
    'description': v.All(str),
    'wrappers': v.All(list)
})

PROJECT = v.Schema({
    v.Required('name'): v.All(str),
    v.Required('jobs'): v.All(list),
    'description': v.All(str)
}, extra=True)

PUBLISHER = v.Schema({
    v.Required('name'): v.All(str),
    v.Required('publishers'): v.All(list),
    'description': v.All(str)
})


def normalize(s):
    "Normalize string for comparison."
    return s.lower().replace("_", "-")


def check_alphabetical():
    """Check that the projects are in alphabetical order
    and that indenting looks correct"""

    print("Checking jenkins/jobs/projects.yaml")
    print("===================================")

    # Note that the file has different sections and we need to check
    # entries within these sections only
    errors = False
    last = ""
    count = 1
    for line in open('jenkins/jobs/projects.yaml', 'r'):
        if line.startswith('    name: '):
            i = line.find(' name: ')
            current = line[i + 7:].strip()
            if normalize(last) > normalize(current):
                print("  Wrong alphabetical order: %(last)s, %(current)s" %
                      {"last": last, "current": current})
                errors = True
            last = current
        if (len(line) - len(line.lstrip(' '))) % 2 != 0:
            print("Line %(count)s not indented by multiple of 2:\n\t%(line)s" %
                  {"count": count, "line": line})
            errors = True

        count = count+1

    if errors:
        print("Found errors in jenkins/jobs/projects.yaml!\n")
    else:
        print("No errors found in jenkins/jobs/projects.yaml!\n")

    return errors


def validate_jobs():
    """Minimal YAML file validation."""

    count = 0
    errors = False

    print("Validating YAML files")
    print("=====================")

    for job_file in glob.glob('jenkins/jobs/*.yaml'):
        jobs = local_yaml.load(io.open(job_file, 'r', encoding='utf-8'))
        for item in jobs:
            if 'builder' in item:
                schema = BUILDER
                entry = item['builder']
            elif 'job' in item:
                schema = JOB
                entry = item['job']
            elif 'job-group' in item:
                schema = JOB_GROUP
                entry = item['job-group']
            elif 'job-template' in item:
                schema = JOB_TEMPLATE
                entry = item['job-template']
            elif 'project' in item:
                schema = PROJECT
                entry = item['project']
            elif 'publisher' in item:
                schema = PUBLISHER
                entry = item['publisher']
            elif 'wrapper' in item:
                continue
            elif 'defaults' in item:
                continue
            else:
                print("Unknown entry in file %s" % job_file)
                print(item)
            try:
                schema(entry)
            except Exception as e:
                print("Failure: %s" % e)
                print("Failure in file %s" % job_file)
                print("Failure parsing item:")
                print(item)
                count += 1
                errors = True

            # NOTE(pabelanger): Make sure console-log is our last publisher
            # defined. We use the publisher to upload logs from zuul-launcher.
            result = _check_console_log_publisher(schema, entry)
            result += _check_tox_builder(schema, entry)
            if result:
                print(job_file)
                count += result
                errors = True

    print("%d errors found validating YAML files in jenkins/jobs/*.yaml.\n" % count)
    return errors


def _check_console_log_publisher(schema, entry):
    count = 0
    if schema == JOB or schema == JOB_TEMPLATE:
        if 'publishers' in entry:
            if 'console-log' in entry['publishers'] and \
                    entry['publishers'][-1] != 'console-log':
                print("ERROR: The console-log publisher MUST be the last "
                      "publisher in '%s':" % entry['name'])
                count += 1
    return count


def _check_tox_builder(schema, entry):
    count = 0
    if schema == JOB or schema == JOB_TEMPLATE:
        if 'builders' in entry:
            for b in entry['builders']:
                # Test for dict, coming from "tox:"
                if isinstance(b, dict):
                    if 'tox' in b:
                        print("ERROR: Use 'run-tox' instead of 'tox' "
                              "builder in '%s':" % entry['name'])
                        count += 1
                # And test for "tox" without arguments
                elif isinstance(b, str) and b == 'tox':
                    print("ERROR: Use 'run-tox' instead of 'tox' "
                          "builder in '%s':" % entry['name'])
                    count += 1
    return count


class ServiceTypeValidator(object):
    # NOTE(dhellmann): This class will move to os-service-types when
    # that repo is ready to start accepting code.

    # The location of the service-types-authority data.
    _URL = 'https://service-types.openstack.org/service-types.json'  # noqa

    def __init__(self):
        # FIXME(dhellmann): Improve error handling and add caching.
        self._raw = requests.get(self._URL).json()
        # Store a mapping from the project name to the service
        # data. Include api_reference_project names when present so
        # that validation code can look up either type of project.
        by_project = {}
        for s in self._raw['services']:
            for key in ['project', 'api_reference_project']:
                name = s.get(key)
                if name:
                    by_project[self._canonical_project_name(name)] = s
        self._raw['by_project'] = by_project

    def _canonical_project_name(self, name):
        "Convert repo name to project name."
        return name.rpartition('/')[-1]

    @property
    def url(self):
        "The URL from which the data was retrieved."
        return self._URL

    @property
    def version(self):
        "The version of the data."
        return self._raw['version']

    @property
    def forward(self):
        "Mapping service type names to their aliases."
        return copy.deepcopy(self._raw['forward'])

    @property
    def reverse(self):
        "Mapping aliases to their service type names."
        return copy.deepcopy(self._raw['reverse'])

    @property
    def services(self):
        return copy.deepcopy(self._raw['services'])

    def get_data_for_project(self, name):
        """Return the data value associated with the project.

        :param name: A repository or project name in the form
            ``'openstack/project'`` or just ``'project'``.
        :type name: str
        :returns: dict
        :raises: ValueError

        """
        key = name.rpartition('/')[-1]
        try:
            return self._raw['by_project'][key]
        except KeyError:
            raise ValueError(
                'No service_type was found for {}'.format(key),
            )


# The jobs for which the service type needs to be checked
_API_JOBS = ['install-guide-jobs', 'api-guide-jobs', 'api-ref-jobs']


def validate_service_types():
    print("Validating Service Types")
    print("========================")
    count = 0
    # Load the current service-type-authority data
    service_types = ServiceTypeValidator()
    # Load the project job definitions
    with io.open('jenkins/jobs/projects.yaml', 'r', encoding='utf-8') as f:
        file_contents = local_yaml.load(f.read())
    for item in file_contents:
        project = item.get('project', {})
        for job in project.get('jobs', []):
            for api_job in _API_JOBS:
                if api_job not in job:
                    continue
                try:
                    proj_data = service_types.get_data_for_project(
                        project['name'])
                except ValueError:
                    print('ERROR: Found service type reference "{}" for {} in {} '
                          'but not in authority list {}'.format(
                              job[api_job]['service'],
                              api_job,
                              project['name'],
                              service_types.url))
                    count +=1
                else:
                    actual = job[api_job]['service']
                    expected = proj_data['service_type']
                    if actual != expected:
                        print('ERROR: Found service "{}" for {} '
                              'in {} but expected "{}"'.format(
                                  job[api_job]['service'],
                                  api_job,
                                  project['name'],
                                  expected))
                        count += 1
    print('Found {} errors in service type settings '
          'in jenkins/jobs/projects.yaml\n'.format(
              count))
    return count


def check_all():
    errors = validate_jobs()
    errors = errors or validate_service_types()  # skip if formatting errors
    errors = check_alphabetical() or errors

    if errors:
        print("Found errors in jenkins/jobs/*.yaml!")
    else:
        print("No errors found in jenkins/jobs/*.yaml!")

    return errors

if __name__ == "__main__":
    sys.exit(check_all())
