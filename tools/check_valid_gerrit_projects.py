#!/usr/bin/env python3
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
import urllib.error
import urllib.request
import yaml


@contextlib.contextmanager
def tempdir():
    try:
        reqroot = tempfile.mkdtemp()
        yield reqroot
    finally:
        shutil.rmtree(reqroot, ignore_errors=True)


def check_repo(repo_path, default_branch):
    found_errors = 0

    print("Checking git repo '%s':" % repo_path)
    with tempdir() as repopath:
        repo = git.Repo.clone_from(repo_path, repopath)
        remotes = repo.git.branch('--remote')
        branches = [r.strip() for r in remotes.splitlines() if r.strip()]
        print("  Remote branches:")
        for r in branches:
            print("    %s" % r)
        if 'origin/%s' % default_branch in branches:
            print("  %s branch exists." % default_branch)
        else:
            found_errors += 1
            print("  ERROR: No %s branch exists" % default_branch)
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
        # Check that no zuul files are in here
        for branch in branches:
            print("Testing branch %s" % branch)
            if 'origin/HEAD' in branch:
                continue
            repo.git.checkout(branch)
            head = repo.head.commit.tree
            for z in ['zuul.yaml', '.zuul.yaml', 'zuul.d', '.zuul.d']:
                if z in head:
                    found_errors += 1
                    print("  ERROR: Found %s on branch %s" % (z, branch))
                    print("    Remove any zuul config files before import.")

    # Just an empty line for nicer formatting
    print("")
    return found_errors


# Check that name exists in set project_names
def check_project_exists(name, project_names):

    if name not in project_names:
        print("  Error: project %s does not exist in gerrit" % name)
        return 1
    return 0


def check_zuul_main(zuul_main, projects):
    found_errors = 0

    main_content = yaml.safe_load(open(zuul_main, 'r'))

    print("Checking %s" % zuul_main)

    project_names = set()
    for p in projects:
        name = p.get('project')
        project_names.add(name)

    # Check that for each gerrit source, we have a project defined in gerrit.
    for tenant in main_content:
        t = tenant.get('tenant')
        if not t:
            continue
        sources = t.get('source')
        if sources and sources.get('gerrit'):
            for project_types in sources['gerrit']:
                for entry in sources['gerrit'][project_types]:
                    if isinstance(entry, dict):
                        if 'projects' in entry:
                            for x in entry['projects']:
                                found_errors += check_project_exists(
                                    x, project_names)
                        else:
                            for x in entry.keys():
                                found_errors += check_project_exists(
                                    x, project_names)
                    else:
                        found_errors += check_project_exists(
                            entry, project_names)

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
    parser.add_argument(
        'zuul_main_file',
        help='Path to zuul/main.yaml',
    )
    args = parser.parse_args()

    projects = yaml.safe_load(open(args.infile, 'r'))

    VALID_LABELS = ["acl-config", "description", "docimpact-group",
                    "groups", "homepage", "options", "project",
                    "upstream", "use-storyboard", "cgit-alias",
                    "default-branch"]
    VALID_SCHEMES = ['https://', 'http://', 'git://']
    DESCRIPTION_REQUIRED = ['openstack', 'openstack-infra', 'openstack-dev',
                            'stackforge']
    VALID_OPTIONS = ['delay-release', 'translate']
    CGIT_ALIAS_SITES = ['zuul-ci.org']

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
        if not re.match(r'[^/]+/[^/]+', name):
            # name must have one and only one slash
            found_errors += 1
            print(
                "ERROR: Project %s must have one and only one slash (/)"
                % name)
        if re.search(r'[^A-Za-z0-9./_-]', name):
            # name can only consist of the characters A-Za-z0-9./_-
            found_errors += 1
            print(
                "ERROR: Project %s has characters outside A-Za-z0-9./_-"
                % name)
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
        if upstream:
            default_branch = p.get('default-branch', 'master')
            openstack_repo = 'https://opendev.org/%s' % name
            try:
                # Check to see if we have already imported the project into
                # OpenStack, if so skip checking upstream.
                urllib.request.urlopen(openstack_repo)
            except urllib.error.HTTPError:
                # We haven't imported the repo yet, make sure upstream is
                # valid.
                found_errors += check_repo(upstream, default_branch)
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
        # Check for valid cgit aliases
        cgit_alias = p.get('cgit_alias')
        if cgit_alias:
            if not isinstance(cgit_alias, dict):
                found_errors += 1
                print("ERROR: cgit alias in project %s must be a dict" %
                      (name,))
            else:
                if 'site' not in cgit_alias or 'path' not in cgit_alias:
                    found_errors += 1
                    print("ERROR: cgit alias in project %s must have "
                          "a site and path" % (name,))
                else:
                    site = cgit_alias['site']
                    path = cgit_alias['path']
                    if path.startswith('/'):
                        found_errors += 1
                        print("ERROR: cgit alias path in project %s must "
                              "not begin with /" % (name,))
                    if site not in CGIT_ALIAS_SITES:
                        found_errors += 1
                        print("ERROR: cgit alias site in project %s is "
                              "not valid" % (name,))
        # Check for valid options
        for option in p.get('options', []):
            if option not in VALID_OPTIONS:
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
        # Check that groups is a list
        groups = p.get('groups')
        if (groups and not isinstance(groups, list)):
            found_errors += 1
            print("Error: groups entry for project %s is not a list." % name)

    found_errors += check_zuul_main(args.zuul_main_file, projects)
    if found_errors:
        print("Found %d error(s) in %s" % (found_errors, args.infile))
        sys.exit(1)


if __name__ == '__main__':
    main()
