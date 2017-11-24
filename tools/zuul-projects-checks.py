#!/usr/bin/env python

# Copyright 2017 SUSE Linux GmbH
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

import sys

import yaml


projects_yaml = 'zuul.d/projects.yaml'
projects = yaml.safe_load(open(projects_yaml))


def check_system_templates():
    """Check that each repo has a system-required template."""

    errors = False
    print("\nChecking for usage of system-required")
    print("=====================================")
    for entry in projects:
        project = entry['project']
        try:
            correct = False
            for template in project['templates']:
                if template == 'system-required':
                    correct = True
            if not correct:
                raise
        except:
            print("ERROR: Project %s has no system-required template" %
                  project['name'])
            errors = True

    if not errors:
        print("... all fine.")
    return errors


def normalize(s):
    "Normalize string for comparison."
    return s.lower().replace("_", "-")


def check_projects_sorted():
    """Check that the projects are in alphabetical order per section."""

    print("\nChecking project list for alphabetical order")
    print("============================================")

    errors = False
    last = ""
    for entry in projects:
        current = entry['project']['name']
        if (normalize(last) > normalize(current)):
            print("  ERROR: Wrong alphabetical order: %(last)s, %(current)s" %
                  {"last": last, "current": current})
            errors = True
        last = current

    if not errors:
        print("... all fine.")
    return errors


def check_release_jobs():
    """Minimal release job checks."""

    release_templates = [
        'release-openstack-server',
        'publish-to-pypi',
        'publish-to-pypi-neutron',
        'publish-to-pypi-horizon',
        'puppet-release-jobs',
        'nodejs4-publish-to-npm',
        'nodejs6-publish-to-npm',
        'xstatic-publish-jobs'
    ]

    errors = False
    print("\nChecking release jobs")
    print("======================")
    for entry in projects:
        project = entry['project']
        name = project['name']
        found = [tmpl for tmpl in project['templates']
                 if tmpl in release_templates]
        if len(found) > 1:
            errors = True
            print("  ERROR: Found multiple release jobs for %s:" % name)
            for x in found:
                print("    %s" % x)
            print("  Use only one of them.")

    if not errors:
        print("... all fine.")
    return errors


def check_pipeline(project, job_pipeline, pipeline_name):

    errors = False

    for job in job_pipeline:
        if isinstance(job, dict):
            for name in job:
                if ('voting' in job[name]
                    and (not job[name]['voting'])):
                    errors = True
                    print("  Found non-voting job in %s:" % pipeline_name)
                    print("    project: %s" % project['name'])
                    print("    job: %s" % name)
    return errors


def check_pipelines(project, pipeline_name):

    errors = False

    if pipeline_name in project and 'jobs' in project[pipeline_name]:
        errors = check_pipeline(project, project[pipeline_name]['jobs'],
                                pipeline_name)
    return errors


def check_voting():
    errors = False
    print("\nChecking voting status of jobs")
    print("==============================")

    for entry in projects:
        project = entry['project']
        errors |= check_pipelines(project, 'gate')
        errors |= check_pipelines(project, 'experimental')
        errors |= check_pipelines(project, 'post')
        errors |= check_pipelines(project, 'periodic')
        errors |= check_pipelines(project, 'periodic-stable')

    if errors:
        print(" Note the following about non-voting jobs in pipelines:")
        print(" * Never run non-voting jobs in gate pipeline, they just")
        print("   waste resources, remove such jobs.")
        print(" * Experimental, periodic, and post pipelines are always")
        print("   non-voting. The 'voting: false' line is redundant, remove")
        print("   it.")
    else:
        print("... all fine.")
    return errors


def check_all():

    errors = check_system_templates()
    errors = check_projects_sorted() or errors
    errors = check_release_jobs() or errors
    errors = check_voting() or errors

    if errors:
        print("\nFound errors in zuul.d/projects.yaml!\n")
    else:
        print("\nNo errors found in zuul.d/projects.yaml!\n")
    return errors


if __name__ == "__main__":
    sys.exit(check_all())
