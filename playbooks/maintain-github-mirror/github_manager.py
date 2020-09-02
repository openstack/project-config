#!/usr/bin/python3
#
# Copyright 2020 Thierry Carrez <thierry@openstack.org>
# All Rights Reserved.
#
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

import argparse
import os
import sys
import time

import github
import requests
from requests.packages import urllib3
import yaml


# Turn of warnings about bad SSL config.
# https://urllib3.readthedocs.io/en/latest/advanced-usage.html#ssl-warnings
urllib3.disable_warnings()

DESC_SUFFIX = ' Mirror of code maintained at opendev.org.'
ARCHIVE_ORG = 'openstack-archive'
DEFAULT_TEAM_ID = 73197
PR_CLOSING_TEXT = (
    "Thank you for your contribution!\n\n"
    "This GitHub repository is just a mirror of %(url)s, where development "
    "really happens. Pull requests proposed on GitHub are automatically "
    "closed.\n\n"
    "If you are interested in pushing this code upstream, please note "
    "that OpenStack development uses Gerrit for change proposal and code "
    "review.\n\n"
    "If you have never contributed to OpenStack before, please see:\n"
    "https://docs.openstack.org/contributors/code-and-documentation/"
    "quick-start.html"
    "\n\nFeel free to reach out to the First Contact SIG by sending an "
    "email to the openstack-discuss list with the tag '[First Contact]' "
    "in the subject line. To email the mailing list, you must first "
    "subscribe which can be done here:\n"
    "http://lists.openstack.org/cgi-bin/mailman/listinfo/openstack-discuss"
)


def homepage(repo):
    return 'https://opendev.org/' + repo


def reponame(org, fullname):
    owner, name = fullname.split('/')
    if org.login != owner:
        raise ValueError(f'{fullname} does not match target org ({org.login})')
    return name


def load_from_project_config(project_config, org='openstack'):
    print('Loading project config...')
    pc = {}
    proj_yaml_filename = os.path.join(project_config, 'gerrit/projects.yaml')
    with open(proj_yaml_filename, 'r') as proj_yaml:
        for project in yaml.safe_load(proj_yaml):
            if project['project'].startswith(org + '/'):
                desc = project.get('description', '')
                if desc and desc[-1:] != '.':
                    desc += '.'
                desc += DESC_SUFFIX
                pc[project['project']] = desc
    print(f'\rLoaded {len(pc)} project descriptions from configuration.')
    return pc


def list_repos_in_zuul(project_config, tenant='openstack', org='openstack'):
    print('Loading Zuul repos...')
    repos = set()
    main_yaml_filename = os.path.join(project_config, 'zuul/main.yaml')
    with open(main_yaml_filename, 'r') as main_yaml:
        for t in yaml.safe_load(main_yaml):
            if t['tenant']['name'] == tenant:
                for ps, pt in t['tenant']['source']['gerrit'].items():
                    for elem in pt:
                        if type(elem) is dict:
                            for k, v in elem.items():
                                if k.startswith(org + '/'):
                                    repos.add(k)
                        else:
                            if elem.startswith(org + '/'):
                                repos.add(elem)
    print(f'Loaded {len(repos)} repositories from Gerrit.')
    return repos


def list_repos_in_governance(governance, org='openstack'):
    print('Loading governance repos...')
    repos = set()

    proj_yaml_filename = os.path.join(governance, 'reference/projects.yaml')
    with open(proj_yaml_filename, 'r') as proj_yaml:
        for pname, project in yaml.safe_load(proj_yaml).items():
            for dname, deliv in project.get('deliverables', dict()).items():
                for r in deliv['repos']:
                    if r.startswith(org + '/'):
                        repos.add(r)

    extrafiles = ['sigs-repos.yaml',
                  'technical-committee-repos.yaml',
                  'user-committee-repos.yaml']
    for extrafile in extrafiles:
        yaml_filename = os.path.join(governance, 'reference', extrafile)
        if not os.path.exists(yaml_filename):
            print(f'Skipping {extrafile} as it no longer exists')
            continue
        with open(yaml_filename, 'r') as extra_yaml:
            for pname, project in yaml.safe_load(extra_yaml).items():
                for r in project:
                    if r['repo'].startswith(org + '/'):
                        repos.add(r['repo'])
    print(f'Loaded {len(repos)} repositories from governance.')
    return repos


def load_github_repositories(org):
    print('Loading GitHub repository list from GitHub...')
    gh_repos = {}
    for repo in org.get_repos():
        gh_repos[repo.full_name] = repo
    print(f'Loaded {len(gh_repos)} repositories from GitHub.     ')
    return gh_repos


def transfer_repository(repofullname, newowner=ARCHIVE_ORG):
    # Transfer repository is not yet supported by PyGitHub, so call directly
    token = os.environ['GITHUB_TOKEN']
    url = f'https://api.github.com/repos/{repofullname}/transfer'
    res = requests.post(url,
                        headers={'Authorization': f'token {token}'},
                        json={'new_owner': newowner})
    if res.status_code != 202:
        raise github.GithubException(res.status_code, res.text)


def archive_repository(archive_org, shortname):
    repository = archive_org.get_repo(shortname)
    repository.edit(archived=True)


def create_repository(org, repofullname, desc, homepage):
    name = reponame(org, repofullname)
    org.create_repo(name=name,
                    description=desc,
                    homepage=homepage,
                    has_issues=False,
                    has_projects=False,
                    has_wiki=False,
                    team_id=DEFAULT_TEAM_ID)


def update_repository(org, repofullname, desc, homepage):
    name = reponame(org, repofullname)
    repository = org.get_repo(name)
    repository.edit(description=desc, homepage=homepage)


def close_pull_request(org, repofullname, github_pr):
    github_pr.create_issue_comment(
        PR_CLOSING_TEXT % {'url': homepage(repofullname)})
    github_pr.edit(state="closed")


def main(args=sys.argv[1:]):
    parser = argparse.ArgumentParser()
    parser.add_argument(
        'project_config',
        help='directory containing the project-config repository')
    parser.add_argument(
        'governance',
        help='directory containing the governance repository')
    parser.add_argument(
        '--dryrun',
        default=False,
        help='do not actually do anything',
        action='store_true')
    args = parser.parse_args(args)

    try:
        gh = github.Github(os.environ['GITHUB_TOKEN'])
        org = gh.get_organization('openstack')
        archive_org = gh.get_organization(ARCHIVE_ORG)
    except KeyError:
        print('Aborting: missing GITHUB_TOKEN environment variable')
        sys.exit(1)

    if args.dryrun:
        print('Running in dry run mode, no action will be actually taken')

    # Load data from Gerrit and GitHub
    gerrit_descriptions = load_from_project_config(args.project_config)
    in_governance = list_repos_in_governance(args.governance)
    in_zuul = list_repos_in_zuul(args.project_config)

    if in_governance != in_zuul:
        print("\nWarning, projects defined in Zuul do not match governance:")

        print("\nIn Governance but not in Zuul (should be cleaned up):")
        for repo in in_governance.difference(in_zuul):
            print(repo)

        print("\nIn Zuul but not in Governance (retirement in progress?):")
        for repo in in_zuul.difference(in_governance):
            print(repo)
        print()

    github_repos = load_github_repositories(org)
    in_github = set(github_repos.keys())

    print("\nUpdating repository descriptions:")
    for repo in in_github.intersection(in_zuul):
        if ((github_repos[repo].description != gerrit_descriptions[repo])
           or (github_repos[repo].homepage != homepage(repo))):
            print(repo, end=' - ', flush=True)
            if args.dryrun:
                print('nothing done (--dryrun)')
            else:
                update_repository(org, repo,
                                  gerrit_descriptions[repo],
                                  homepage(repo))
                print('description updated')
                time.sleep(1)

    print("\nArchiving repositories that are in GitHub but not in Zuul:")
    for repo in in_github.difference(in_zuul):
        print(repo, end=' - ', flush=True)
        if args.dryrun:
            print('nothing done (--dryrun)')
        else:
            transfer_repository(repo)
            print(f'moved to {ARCHIVE_ORG}', end=' - ', flush=True)
            time.sleep(10)
            archive_repository(archive_org, reponame(org, repo))
            print('archived')
            time.sleep(1)

    print("\nCreating repos that are in Zuul & governance but not in Github:")
    for repo in (in_zuul.intersection(in_governance)).difference(in_github):
        print(repo, end=' - ', flush=True)
        if args.dryrun:
            print('nothing done (--dryrun)')
        else:
            create_repository(org, repo,
                              gerrit_descriptions[repo],
                              homepage(repo))
            print('created')
            time.sleep(1)

    print("\nIterating through all Github repositories to close PRs:")
    for repo, gh_repository in github_repos.items():
        for req in gh_repository.get_pulls("open"):
            print(f'Closing PR#{req.number} in {repo}', end=' - ', flush=True)
            if args.dryrun:
                print('nothing done (--dryrun)')
            else:
                close_pull_request(org, repo, req)
                print('closed')
                time.sleep(1)
    print("Done.")


if __name__ == '__main__':
    main()
