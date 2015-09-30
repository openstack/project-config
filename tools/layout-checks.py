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

import yaml
import sys

layout = yaml.load(open('zuul/layout.yaml'))


def check_merge_template():
    """Check that each job has a merge-check template."""

    errors = False
    print("\nChecking for usage of merge template")
    print("====================================")
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
    """Check that the projects are in alphabetical order per section."""

    print("Checking sections for alphabetical order")
    print("========================================")
    # Note that the file has different sections and we need to sort
    # entries within these sections.
    errors = False
    # Skip all entries before the first section header
    firstEntry = True
    last = ""
    for line in open('zuul/layout.yaml', 'r'):
        if line.startswith('# Section:'):
            last = ""
            section = line[10:].strip()
            print("Checking section '%s'" % section)
            firstEntry = False
        if line.startswith('  - name: ') and not firstEntry:
            current = line[10:].strip()
            if (normalize(last) > normalize(current) and
                last != 'z/tempest'):
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
        count = count + 1

    return errors

def check_all():
    errors = False               # this can be removed when the following check is re-enabled
    # errors = check_sections()  # disabling alphabetical order check for mass stackforge rename
    errors = check_merge_template() or errors
    errors = check_formatting() or errors

    if errors:
        print("\nFound errors in layout.yaml!")
    else:
        print("\nNo errors found in layout.yaml!")
    return errors

if __name__ == "__main__":
    sys.exit(check_all())
