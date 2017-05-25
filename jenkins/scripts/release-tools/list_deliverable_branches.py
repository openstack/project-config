#!/usr/bin/env python

#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

"""Lists the branches in the modified deliverable files.
"""

from __future__ import print_function

import argparse
import os.path
import re
import subprocess

import yaml


PRE_RELEASE_RE = re.compile('''
    \.(\d+(?:[ab]|rc)+\d*)$
''', flags=re.VERBOSE | re.UNICODE)


def find_modified_deliverable_files(reporoot):
    "Return a list of files modified by the most recent commit."
    results = subprocess.check_output(
        ['git', 'diff', '--name-only', '--pretty=format:', 'HEAD^'],
        cwd=reporoot,
    )
    filenames = [
        l.strip()
        for l in results.splitlines()
        if l.startswith('deliverables/')
    ]
    return filenames


def get_modified_deliverable_file_content(reporoot, filenames):
    """Return a sequence of tuples containing the branches.

    Return tuples containing (repository name, branch name, git
    reference)

    """
    # Determine which deliverable files to process by taking our
    # command line arguments or by scanning the git repository
    # for the most recent change.
    deliverable_files = filenames
    if not deliverable_files:
        deliverable_files = find_modified_deliverable_files(
            reporoot
        )

    for basename in deliverable_files:
        filename = os.path.join(reporoot, basename)
        if not os.path.exists(filename):
            # The file must have been deleted, skip it.
            continue
        with open(filename, 'r') as f:
            deliverable_data = yaml.load(f.read())

        # Map the release version to the release contents so we can
        # easily get a list of repositories for stable branches.
        releases_by_version = {
            r['version']: r
            for r in deliverable_data.get('releases', [])
        }

        for branch in deliverable_data.get('branches', []):
            location = branch['location']

            if isinstance(location, dict):
                for repo, sha in sorted(location.items()):
                    yield (repo, branch['name'], sha)

            else:
                # Assume a single location string that is a valid
                # reference in the git repository.
                for proj in releases_by_version[location]['projects']:
                    yield (proj['repo'], branch['name'], branch['location'])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        'deliverable_file',
        nargs='*',
        help='paths to YAML files specifying releases',
    )
    parser.add_argument(
        '--releases-repo', '-r',
        default='.',
        help='path to the releases repository for automatic scanning',
    )
    args = parser.parse_args()

    results = get_modified_deliverable_file_content(
        args.releases_repo,
        args.deliverable_file,
    )
    for r in results:
        print(' '.join(r))
    return 0


if __name__ == '__main__':
    main()
