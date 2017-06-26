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
import os
import re
import shutil
import sys
import tempfile
import yaml


@contextlib.contextmanager
def tempdir():
    try:
        reqroot = tempfile.mkdtemp()
        yield reqroot
    finally:
        shutil.rmtree(reqroot, ignore_errors=True)


def check_repo(repo_path):
    found_errors = 0

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
            print("  ERROR: No master branch exists")
        if 'origin/stable' in branches:
            found_errors += 1
            print("  ERROR: A branch named 'stable' exists, this will"
                  " break future\n"
                  "         creation of stable/RELEASEbranches.\n"
                  "         Delete the branch on your upstream project.")
        if 'origin/feature' in branches:
            found_errors += 1
            print("  ERROR: A branch named 'feature' exists, this will break "
                  "future\n"
                  "         creation of feature/NAME branches.\n"
                  "         Delete the branch on your upstream project.")
        if repo.tags:
            print("  Found the following tags:")
            for tag in repo.tags:
                print("    %s" % tag)
        else:
            print("  Found no tags.")
    # Just an empty line for nicer formatting
    print("")
    return found_errors


def main():
    found_errors = 0

    parser = argparse.ArgumentParser()
    parser.add_argument('-v', '--verbose',
                        dest='verbose',
                        default=False,
                        action='store_true')
    parser.add_argument(
        'infile',
        help='Path to gerrit/projects.yaml',
    )
    parser.add_argument(
        'acldir',
        help='Path to gerrit/acl',
    )
    args = parser.parse_args()

    projects = yaml.load(open(args.infile, 'r'))

    VALID_LABELS = ["acl-config", "description", "docimpact-group",
                    "groups", "homepage", "options", "project",
                    "upstream", "upstream-prefix", "use-storyboard"]
    VALID_SCHEMES = ['https://', 'http://', 'git://']
    DESCRIPTION_REQUIRED = ['openstack', 'openstack-infra', 'openstack-dev',
                            'stackforge']
    VALID_OPTIONS = ['delay-release', 'track-upstream', 'translate']

    for p in projects:
        name = p.get('project')
        repo_group, repo_name = name.split('/')
        if not name:
            # not a project
            found_errors += 1
            print("ERROR: Entry is not a project %s" % p)
            continue
        if args.verbose:
            print('Checking %s' % name)
        description = p.get('description')

        # *very* simple check for common description mistakes
        badwords = (
            # (words), what_words_should_be
            (('openstack', 'Openstack', 'Open Stack'), 'OpenStack'),
            (('Devstack', 'devstack'), 'DevStack'),
            (('astor', 'Astor', 'astra', 'Astra', 'astara'), 'Astara')
        )
        if description:
            # newlines here mess up cgit "repo.desc
            if '\n' in description:
                found_errors += 1
                print("ERROR: Descriptions should not contain newlines:")
                print('  "%s"' % description)

            for words, should_be in badwords:
                for word in words:
                    # look for the bad word hanging out on it's own.  Only
                    # trick is "\b" doesn't consider "-" or '.' as a
                    # word-boundary, so ignore it if it looks like some
                    # sort of job-description (e.g. "foo-devstack-bar") or
                    # a url ("foo.openstack.org")
                    if re.search(r'(?<![-.])\b%s\b' % word, description):
                        print("ERROR: project %s, description '%s': "
                              "contains wrong word '%s', it should be '%s'" %
                              (name, description, word, should_be))
                        found_errors += 1

        if not description and repo_group in DESCRIPTION_REQUIRED:
            found_errors += 1
            print("ERROR: Project %s has no description" % name)
            continue
        # Check upstream URL
        # Allow git:// and https:// URLs for importing upstream repositories,
        # but not git@
        upstream = p.get('upstream')
        if upstream and 'track-upstream' not in p.get('options', []):
            openstack_repo = 'https://git.openstack.org/%s' % name
            try:
                # Check to see if we have already imported the project into
                # OpenStack, if so skip checking upstream.
                check_repo(openstack_repo)
            except git.exc.GitCommandError:
                # We haven't imported the repo yet, make sure upstream is
                # valid.
                found_errors += check_repo(upstream)
        if upstream:
            for prefix in VALID_SCHEMES:
                if upstream.startswith(prefix):
                    break
            else:
                found_errors += 1
                print('ERROR: Upstream URLs should use a scheme in %s, '
                      'found %s in %s' %
                      (VALID_SCHEMES, p['upstream'], name))
        # Check for any wrong entries
        for entry in p:
            for label in VALID_LABELS:
                if entry == label:
                    break
            else:
                found_errors += 1
                print("ERROR: Unknown keyword '%s' in project %s" %
                      (entry, name))
        # Check for valid options
        for option in p.get('options', []):
            if not option in VALID_OPTIONS:
                found_errors += 1
                print("ERROR: Unknown option '%s' in project %s" %
                      (option, name))
        # Check redundant acl-config
        acl_config = p.get('acl-config')
        if acl_config:
            if acl_config.endswith(name + '.config'):
                found_errors += 1
                print("ERROR: Project %s has redundant acl_config line, "
                      "remove it." % name)
            if not acl_config.startswith('/home/gerrit2/acls/'):
                found_errors += 1
                print("ERROR: Project %s has wrong acl_config line, "
                      "fix the path." % name)
            acl_file = os.path.join(args.acldir,
                                    acl_config[len('/home/gerrit2/acls/'):])
            if not os.path.isfile(acl_file):
                found_errors += 1
                print("ERROR: Project %s has non existing acl_config line" %
                      name)
        else:
            # Check that default file exists
            acl_file = os.path.join(args.acldir, name + ".config")
            if not os.path.isfile(acl_file):
                found_errors += 1
                print("ERROR: Project %s has no default acl-config file" %
                      name)
        # Check redundant groups entry:
        # By default the groups entry is repo_name, no need to add this.
        groups = p.get('groups')
        storyboard = p.get('use-storyboard', False)
        if (groups and len(groups) == 1 and groups[0] == repo_name
                and not storyboard):
            found_errors += 1
            print("ERROR: Non-StoryBoard project %s has default groups entry, "
                  "remove it" % name)

    if found_errors:
        print("Found %d error(s) in %s" % (found_errors, args.infile))
        sys.exit(1)


if __name__ == '__main__':
    main()
