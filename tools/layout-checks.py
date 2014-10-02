#!/usr/bin/python

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

import yaml
import sys

layout = yaml.load(open('zuul/layout.yaml'))


def check_merge_template():
    """Check that each job has a merge-check template."""

    errors = False
    for project in layout['projects']:
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


def check_sections():
    """Check that the openstack/* projects are in alphabetical order."""

    # Note that openstack/ has different sections and we need to sort
    # entries within these sections:
    # Section: OpenStack server projects
    # Section: OpenStack client projects (python-*)
    # Section: oslo projects
    # Section: Other OpenStack projects
    # Section: OpenStack API projects
    # Section: OpenStack documentation projects
    # Record the first project in each section and use that to
    # identify them. This list needs to be adjusted if entries get
    # added.
    section_starters = ['openstack/barbican',
                        'openstack/python-barbicanclient',
                        'openstack/cliff',
                        'openstack/dib-utils',
                        'openstack/compute-api',
                        'openstack/api-site',
                        'openstack-dev/bashate']
    errors = False
    for i in range(0, len(section_starters) - 1):
        print("Checking section from %s to %s" %
              (section_starters[i], section_starters[i + 1]))
        last = layout['projects'][0]['name']
        in_section = False
        for project in layout['projects']:
            current = project['name']
            if current == section_starters[i]:
                in_section = True
                last = current
                continue
            # Did we reach end of section?
            if current == section_starters[i + 1]:
                break
            if not in_section:
                last = current
                continue
            if last == 'z/tempest':
                last = current
                continue
            if normalize(last) > normalize(current):
                print("  Wrong alphabetical order: %(last)s, %(current)s" %
                      {"last": last, "current": current})
                errors = True
            last = current

    return errors


def check_alphabetical():
    """Check that projects are sorted alphabetical."""

    errors = False
    # For now, only check sorting of some projects.
    last = layout['projects'][0]['name']
    for project in layout['projects']:
        current = project['name']
        if not last.startswith(("openstack-dev/", "openstack-infra/",
                                "stackforge/")):
            last = current
            continue
        if normalize(last) > normalize(current):
            print("Wrong alphabetical order: %(last)s, %(current)s" %
                  {"last": last, "current": current})
            errors = True
        last = current
    return errors


def check_all():
    errors = check_sections()
    errors = check_alphabetical() or errors
    errors = check_merge_template() or errors

    if errors:
        print("Found errors in layout.yaml!")
    else:
        print("No errors found in layout.yaml!")
    return errors

if __name__ == "__main__":
    sys.exit(check_all())
