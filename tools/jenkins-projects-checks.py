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

import glob
import sys
import yaml

import voluptuous as v

BUILDER = v.Schema({
    v.Required('name'): v.All(str),
    v.Required('builders'): v.All(list)
}, extra=True)

JOB = v.Schema({
    v.Required('builders'): v.All(list),
    v.Required('name'): v.All(str),
    'description': v.All(str),
    'node': v.All(str),
    'parameters': v.All(list),
    'publishers': v.All(list),
    'wrappers': v.All(list)
})

JOB_GROUP = v.Schema({
    v.Required('name'): v.All(str),
    v.Required('jobs'): v.All(list)
}, extra=True)

JOB_TEMPLATE = v.Schema({
    v.Required('builders'): v.All(list),
    v.Required('name'): v.All(str),
    'node': v.All(str),
    'publishers': v.All(list),
    'wrappers': v.All(list)
})

PROJECT = v.Schema({
    v.Required('name'): v.All(str),
    v.Required('jobs'): v.All(list)
}, extra=True)

PUBLISHER = v.Schema({
    v.Required('name'): v.All(str),
    v.Required('publishers'): v.All(list)
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
        jobs = yaml.load(open(job_file))
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
                print("Failure in file %s" % job_file)
                print("Failure parsing item:")
                print(item)
                count += 1
                errors = True

    print ("%d errors found validating YAML files in jenkins/jobs/*.yaml.\n" % count)
    return errors


def check_all():
    errors = validate_jobs()
    errors = check_alphabetical() or errors

    if errors:
        print("Found errors in jenkins/jobs/*.yaml!")
    else:
        print("No errors found in jenkins/jobs/*.yaml!")

    return errors

if __name__ == "__main__":
    sys.exit(check_all())
