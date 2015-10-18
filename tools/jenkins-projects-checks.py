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

import sys


def normalize(s):
    "Normalize string for comparison."
    return s.lower().replace("_", "-")


def check_alphabetical():
    """Check that the projects are in alphabetical order
    and that indenting looks correct"""

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

    return errors


def check_all():
    errors = check_alphabetical()

    if errors:
        print("Found errors in jenkins/jobs/projects.yaml!")
    else:
        print("No errors found in jenkins/jobs/projects.yaml!")
    return errors

if __name__ == "__main__":
    sys.exit(check_all())
