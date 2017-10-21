#!/usr/bin/env python
#
# Check that gerrit/projects.yaml changes are valid.
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
    try:
        with tempdir() as repopath:
            git.Repo.clone_from(repo_path, repopath)
        print("Can be cloned")
    except Exception as e:
        print("Failure: %s" % e)
        found_errors += 1
    return found_errors


def main():
    found_errors = 0

    parser = argparse.ArgumentParser()
    parser.add_argument('-v', '--verbose',
                        dest='verbose',
                        default=False,
                        action='store_true')
    parser.add_argument(
        'oldfile',
        help='Path to old gerrit/projects.yaml',
    )
    parser.add_argument(
        'newfile',
        help='Path to new gerrit/projects.yaml',
    )
    args = parser.parse_args()

    projects_old = yaml.load(open(args.oldfile, 'r'))
    projects_new = yaml.load(open(args.newfile, 'r'))

    ps_old = {}
    for p in projects_old:
        name = p.get('project')
        ps_old[name] = p

    for p in projects_new:
        name = p.get('project')
        upstream = p.get('upstream')
        if name in ps_old:
            p_old = ps_old[name]
            upstream_old = p_old.get('upstream')
        else:
            upstream_old = ""
        if (upstream != upstream_old and
                'track-upstream' in p.get('options', [])):
            print("%s has changed" % name)
            found_errors += check_repo(upstream)

    if found_errors:
        print("Found %d error(s)" % found_errors)
        sys.exit(1)


if __name__ == '__main__':
    main()
