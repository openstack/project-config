#!/usr/bin/env python
#
# Check that gerrit/projects.yaml contains valid entries.
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
import contextlib
import git
import re
import shutil
import sys
import tempfile
import yaml

found_errors = 0


@contextlib.contextmanager
def tempdir():
    try:
        reqroot = tempfile.mkdtemp()
        yield reqroot
    finally:
        shutil.rmtree(reqroot)


def check_repo(repo_path):
    global found_errors

    print("Checking git repo '%s':" % repo_path)
    with tempdir() as repopath:
        repo = git.Repo.clone_from(repo_path, repopath)
        remotes = repo.git.branch('--remote')
        branches = [r.strip() for r in remotes.splitlines() if r.strip()]
        print ("  Remote branches:")
        for r in branches:
            print("    %s" % r)
        if 'origin/master' in branches:
            print("  Master branch exists.")
        else:
            found_errors += 1
            print("  Error: No master branch exists")
        if repo.tags:
            print("  Found the following tags:")
            for tag in repo.tags:
                print("    %s" % tag)
        else:
            print("  Found no tags.")
    # Just an empty line for nicer formatting
    print("")


def main():
    global found_errors

    parser = argparse.ArgumentParser()
    parser.add_argument('-v', '--verbose',
                        dest='verbose',
                        default=False,
                        action='store_true')
    parser.add_argument(
        'infile',
        help='Path to gerrit/projects.yaml',
    )
    args = parser.parse_args()

    projects = yaml.load(open(args.infile, 'r'))

    VALID_LABELS = ["acl-config", "description", "docimpact-group",
                    "groups", "homepage", "options", "project",
                    "upstream", "upstream-prefix", "use-storyboard"]
    VALID_SCHEMES = ['https://', 'http://', 'git://']
    DESCRIPTION_REQUIRED = ['openstack', 'openstack-infra', 'openstack-dev',
                            'stackforge']

    for p in projects:
        name = p.get('project')
        repo_group = name.split('/')[0]
        if not name:
            # not a project
            found_errors += 1
            print("Error: Entry is not a project %s" % p)
            continue
        if args.verbose:
            print('Checking %s' % name)
        description = p.get('description')

        # *very* simple check for common description mistakes
        badwords = (
            # (words), what_words_should_be
            (('openstack', 'Openstack', 'Open Stack'), 'OpenStack'),
            (('Devstack', 'devstack'), 'DevStack')
        )
        if description:
            for words, should_be in badwords:
                for word in words:
                    # look for the bad word hanging out on it's own.  Only
                    # trick is "\b" doesn't consider "-" or '.' as a
                    # word-boundary, so ignore it if it looks like some
                    # sort of job-description (e.g. "foo-devstack-bar") or
                    # a url ("foo.openstack.org")
                    if re.search(r'(?<![-.])\b%s\b' % word, description):
                        print("Error: %s: should be %s" %
                              (description, should_be))
                        found_errors += 1

        if not description and repo_group in DESCRIPTION_REQUIRED:
            found_errors += 1
            print("Error: Project %s has no description" % name)
            continue
        # Check upstream URL
        # Allow git:// and https:// URLs for importing upstream repositories,
        # but not git@
        upstream = p.get('upstream')
        if upstream and 'track-upstream' not in p.get('options', []):
            check_repo(upstream)
        if upstream:
            for prefix in VALID_SCHEMES:
                if upstream.startswith(prefix):
                    break
            else:
                found_errors += 1
                print('Error: Upstream URLs should use a scheme in %s, '
                      'found %s in %s' %
                      (VALID_SCHEMES, p['upstream'], name))
        # Check for any wrong entries
        for entry in p:
            for label in VALID_LABELS:
                if entry == label:
                    break
            else:
                found_errors += 1
                print("Error: Unknown keyword '%s' in project %s" %
                      (entry, name))

    if found_errors:
        print("Found %d error(s) in %s" % (found_errors, args.infile))
        sys.exit(1)


if __name__ == '__main__':
    main()
