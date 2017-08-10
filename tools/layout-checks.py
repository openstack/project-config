#!/usr/bin/env python

# Copyright 2014 OpenStack Foundation
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

import argparse
import ConfigParser
import copy
import os
import re
import sys

import yaml


layout_yaml = 'zuul/layout.yaml'
layout = yaml.safe_load(open(layout_yaml))

gerrit_yaml = 'gerrit/projects.yaml'
gerrit_config = yaml.safe_load(open(gerrit_yaml))

gerrit_acl_pattern = 'gerrit/acls/%s.config'

def check_merge_template():
    """Check that each job has a merge-check template."""

    errors = False
    print("\nChecking for usage of merge template")
    print("====================================")
    for project in layout['projects']:
        # TODO(jeblair): Temporarily (for the zuul v3 transition)
        # disable this check for infra repos
        if project['name'].startswith('openstack-infra'):
            continue
        if project['name'] == 'z/tempest':
            continue
        try:
            correct = False
            for template in project['template']:
                if template['name'] == 'merge-check':
                    correct = True
            if not correct:
                raise
        except:
            print("Project %s has no merge-check template" % project['name'])
            errors = True
    return errors


def normalize(s):
    "Normalize string for comparison."
    return s.lower().replace("_", "-")


def check_projects_sorted():
    """Check that the projects are in alphabetical order per section."""

    print("Checking project list for alphabetical order")
    print("============================================")
    # Note that the file has different sections and we need to sort
    # entries within these sections.
    errors = False
    # Skip all entries before the project list
    firstEntry = True
    last = ""
    for line in open('zuul/layout.yaml', 'r'):
        if line.startswith('projects:'):
            last = ""
            firstEntry = False
        if line.startswith('  - name: ') and not firstEntry:
            current = line[10:].strip()
            if (normalize(last) > normalize(current)):
                print("  Wrong alphabetical order: %(last)s, %(current)s" %
                      {"last": last, "current": current})
                errors = True
            last = current
    return errors

def check_formatting():
    errors = False
    count = 1

    print("Checking indents")
    print("================")

    for line in open('zuul/layout.yaml', 'r'):
        if (len(line) - len(line.lstrip(' '))) % 2 != 0:
            print("Line %(count)s not indented by multiple of 2:\n\t%(line)s" %
                  {"count": count, "line": line})
            errors = True

        # check for something like
        #  - name : ...
        # which for consistency we like called "name: ..."
        if " : " in line:
            print("Line %(count)s does not align key with ':'\n\t%(line)s" %
                  {"count": count, "line": line})
            errors = True

        count = count + 1

    return errors

def grep(source, pattern):
    """Run regex PATTERN over each line in SOURCE and return
    True if any match found"""
    found = False
    p = re.compile(pattern)
    for line in source:
        if p.match(line):
            found = True
            break
    return found


def check_jobs(joblistfile):
    """Check that jobs have matches"""
    errors = False

    print("\nChecking job section regex expressions")
    print("======================================")

    # The job-list.txt file is created by tox.ini and
    # thus should exist if this is run from tox. If this is manually invoked
    # the file might not exist, in that case skip the test.
    if not os.path.isfile(joblistfile):
        print("Job list file %s does not exist, not checking jobs section"
              % joblistfile)
        return False

    with open(joblistfile, 'r') as f:
        job_list = [line.rstrip() for line in f]

    for jobs in layout['jobs']:
        found = grep(job_list, jobs['name'])
        if not found:
            print ("Regex %s has no matches in job list" % jobs['name'])
            errors = True
        if len(jobs.keys()) == 1:
            print ("Job %s has no attributes in job list" % jobs['name'])
            errors = True

    return errors


def collect_pipeline_jobs(project, pipeline):
    jobs = []
    if pipeline in project:
        # We need to copy the object here to prevent the loop
        # below from modifying the project object.
        jobs = copy.deepcopy(project[pipeline])

    if 'template' in project:
        for template in project['template']:
            # The template dict has a key for each pipeline and a key for the
            # name. We want to filter on the name to make sure it matches the
            # one listed in the project's template list, then collect the
            # specific pipeline we are currently looking at.
            t_jobs = [ _template[pipeline]
                        for _template in layout['project-templates']
                        if _template['name'] == template['name']
                        and pipeline in _template ]
            if t_jobs:
                jobs.append(t_jobs)

    return jobs


def check_empty_check():
    '''Check that each project has at least one check job'''

    print("\nChecking for projects with no check jobs")
    print("====================================")

    for project in layout['projects']:
        # TODO(jeblair): Temporarily (for the zuul v3 transition)
        # disable this check for infra repos
        if project['name'].startswith('openstack-infra'):
            continue
        # z/tempest is a fake project with no check queue
        if project['name'] == 'z/tempest':
            continue
        check_jobs = collect_pipeline_jobs(project, 'check')
        if not check_jobs:
            print("Project %s has no check jobs" % project['name'])
            return True

    return False


def check_empty_gate():
    '''Check that each project has at least one gate job'''

    print("\nChecking for projects with no gate jobs")
    print("====================================")

    for project in layout['projects']:
        # TODO(jeblair): Temporarily (for the zuul v3 transition)
        # disable this check for infra repos
        if project['name'].startswith('openstack-infra'):
            continue
        gate_jobs = collect_pipeline_jobs(project, 'gate')
        if not gate_jobs:
            print("Project %s has no gate jobs" % project['name'])
            return True

    return False


def check_mixed_noops():
    '''Check that no project is mixing both noop and non-noop jobs'''

    print("\nChecking for mixed noop and non-noop jobs")
    print("====================================")

    for project in layout['projects']:
        for pipeline in ['gate', 'check']:
            jobs = collect_pipeline_jobs(project, pipeline)
            if 'noop' in jobs and len(jobs) > 1:
                print("Project %s has both noop and non-noop jobs "
                      "in '%s' pipeline" % (project['name'], pipeline))
                return True

    return False


def check_gerrit_zuul_projects():
    '''Check that gerrit projects have zuul pipelines and vice versa'''
    errors = False

    zuul_projects = [ x['name'] for x in layout['projects'] ]
    gerrit_projects = [ x['project'] for x in gerrit_config ]

    print("\nChecking for gerrit projects with no zuul pipelines")
    print("===================================================")

    for gp in gerrit_projects:
        # TODO(jeblair): Temporarily (for the zuul v3 transition)
        # disable this check for infra repos
        if gp.startswith('openstack-infra'):
            continue

        # Check the gerrit config for a different acl file
        acls = [ x['acl-config'] if 'acl-config' in x else None \
               for x in gerrit_config if x['project'] == gp ]
        if len(acls) != 1:
            errors = True
            print("Duplicate acl config for %s" % gp)
            break

        acl_config = acls.pop()
        if acl_config is None:
            acl_file = gerrit_acl_pattern % gp
        else:
            acl_file = acl_config.replace('/home/gerrit2/acls', 'gerrit/acls')

        config = ConfigParser.ConfigParser()
        config.read(acl_file)

        try:
            ignore = config.get('project', 'state') == 'read only'
            if ignore:
                continue  # Skip inactive projects
        except ConfigParser.NoSectionError:
            pass

        if gp not in zuul_projects:
            print("Project %s is not in %s" % (gp, layout_yaml))
            errors = True

    print("\nChecking for zuul pipelines with no gerrit project")
    print("===================================================")

    for zp in zuul_projects:
        if zp == 'z/tempest':
            continue  # Ignore z/tempest

        if zp not in gerrit_projects:
            print("Project %s is not in %s" % (zp, gerrit_yaml))
            errors = True

    return errors



def check_all():

    parser = argparse.ArgumentParser()
    parser.add_argument(
        'joblistfile',
        help='Path to job-list.txt file',
    )
    args = parser.parse_args()


    errors = check_projects_sorted()
    errors = check_merge_template() or errors
    errors = check_formatting() or errors
    errors = check_empty_check() or errors
    errors = check_empty_gate() or errors
    errors = check_mixed_noops() or errors
    errors = check_gerrit_zuul_projects() or errors
    errors = check_jobs(args.joblistfile) or errors

    if errors:
        print("\nFound errors in layout.yaml!")
    else:
        print("\nNo errors found in layout.yaml!")
    return errors

if __name__ == "__main__":
    sys.exit(check_all())
