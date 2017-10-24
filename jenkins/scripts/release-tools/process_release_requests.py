#!/usr/bin/env python3

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

"""Process all of the release requests in changed files in the commit.
"""

import argparse
import os.path
import re
import sys
import subprocess

import yaml


PRE_RELEASE_RE = re.compile('''
    \.(\d+(?:[ab]|rc)+\d*)$
''', flags=re.VERBOSE | re.UNICODE)

BINDIR = os.path.dirname(sys.argv[0])
RELEASE_SCRIPT = os.path.join(BINDIR, 'release.sh')
BRANCH_SCRIPT = os.path.join(BINDIR, 'make_branch.sh')


def find_modified_deliverable_files(reporoot):
    "Return a list of files modified by the most recent commit."
    results = subprocess.check_output(
        ['git', 'diff', '--name-only', '--pretty=format:', 'HEAD^'],
        cwd=reporoot,
    ).decode('utf-8')
    filenames = [
        l.strip()
        for l in results.splitlines()
        if l.startswith('deliverables/')
    ]
    return filenames


def tag_release(repo, series_name, version, diff_start, hash,
                include_pypi_link, first_full_release, meta_data):
    try:
        subprocess.check_call(
            [RELEASE_SCRIPT, repo, series_name, version,
             diff_start, hash, include_pypi_link,
             first_full_release, meta_data]
        )
    except subprocess.CalledProcessError:
        # The error output from the script will be printed to
        # stderr, so we don't need to do anything else here.
        return 1
    return 0


def make_branch(repo, name, ref):
    try:
        subprocess.check_call([BRANCH_SCRIPT, repo, name, ref])
    except subprocess.CalledProcessError:
        # The error output from the script will be
        # printed to stderr, so we don't need to do
        # anything else here.
        return 1
    return 0


def process_release_requests(reporoot, filenames, meta_data):
    """Return a sequence of tuples containing the new versions.

    Return tuples containing (deliverable name, series name, version
    number, repository name, hash SHA, include pypi link, first full
    version)

    """

    # Determine which deliverable files to process by taking our
    # command line arguments or by scanning the git repository
    # for the most recent change.
    deliverable_files = filenames
    if not deliverable_files:
        deliverable_files = find_modified_deliverable_files(
            reporoot
        )

    error_count = 0

    for basename in deliverable_files:
        filename = os.path.join(reporoot, basename)
        if not os.path.exists(filename):
            # The file must have been deleted, skip it.
            continue
        with open(filename, 'r', encoding='utf-8') as f:
            deliverable_data = yaml.load(f.read())

        # If there are no releases listed in this file, skip it.
        if not deliverable_data.get('releases'):
            continue

        # Map the release version to the release contents so we can
        # easily get a list of repositories for stable branches.
        releases_by_version = {
            r['version']: r
            for r in deliverable_data.get('releases', [])
        }

        # Determine whether announcements should include a PyPI
        # link. Default to no, for service projects, because it is
        # less irksome to fail to include a link to a thing that
        # exists than to link to something that does not.
        include_pypi_link = deliverable_data.get(
            'include-pypi-link',
            False,
        )
        include_pypi_link = 'yes' if include_pypi_link else 'no'

        # The series name is part of the filename, rather than the file
        # body. That causes release.sh to be called with series="_independent"
        # for release:independent projects, and release.sh to use master branch
        # to evaluate fixed bugs.
        series_name = os.path.basename(
            os.path.dirname(os.path.abspath(filename))
        ).lstrip('_')

        all_versions = {
            rel['version']: rel for rel in deliverable_data['releases']
        }
        version = deliverable_data['releases'][-1]['version']
        this_version = all_versions[version]
        final_versions = [
            r['version']
            for r in deliverable_data['releases']
            if not PRE_RELEASE_RE.search(r['version'])
        ]
        first_full_release = 'yes' if (
            final_versions and
            this_version['version'] == final_versions[0]
        ) else 'no'
        diff_start = this_version.get('diff-start', '-')

        # Tag releases.

        for project in this_version['projects']:
            error_count += tag_release(
                project['repo'], series_name, version,
                diff_start, project['hash'], include_pypi_link,
                first_full_release, meta_data,
            )

        # Create branches.

        for branch in deliverable_data.get('branches', []):
            location = branch['location']

            if isinstance(location, dict):
                for repo, sha in sorted(location.items()):
                    error_count += make_branch(repo, branch['name'], sha)

            else:
                # Assume a single location string that is a valid
                # reference in the git repository.
                for proj in releases_by_version[location]['projects']:
                    error_count += make_branch(
                        proj['repo'], branch['name'], branch['location'],
                    )

    return error_count


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--meta-data',
        help='extra metadata to add to the release tag',
    )
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

    return process_release_requests(
        args.releases_repo,
        args.deliverable_file,
        args.meta_data,
    )


if __name__ == '__main__':
    main()
