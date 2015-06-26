#! /usr/bin/env python
# Copyright (C) 2011 OpenStack, LLC.
# Copyright (c) 2013 Hewlett-Packard Development Company, L.P.
# Copyright (c) 2013 OpenStack Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

import argparse
import contextlib
import os
import pkg_resources
import shlex
import shutil
import subprocess
import sys
import tempfile


def run_command(cmd):
    print(cmd)
    cmd_list = shlex.split(str(cmd))
    p = subprocess.Popen(cmd_list, stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE)
    (out, err) = p.communicate()
    if p.returncode != 0:
        raise SystemError(err)
    return (out.strip(), err.strip())


class RequirementsList(object):
    def __init__(self, name):
        self.name = name
        self.reqs = {}
        self.failed = False

    def read_requirements(self, fn, ignore_dups=False, strict=False):
        """ Read a requirements file and optionally enforce style."""
        if not os.path.exists(fn):
            return
        for line in open(fn):
            if strict and '\n' not in line:
                raise Exception("Requirements file %s does not "
                                "end with a newline." % fn)
            if '#' in line:
                line = line[:line.find('#')]
            line = line.strip()
            if (not line or
                    line.startswith('http://tarballs.openstack.org/')):
                continue
            if strict:
                req = pkg_resources.Requirement.parse(line)
            else:
                try:
                    req = pkg_resources.Requirement.parse(line)
                except ValueError:
                    print("Ignoring unparseable requirement in non-strict "
                          "mode: %s" % line)
                    continue
            if (not ignore_dups and strict and req.project_name.lower()
                in self.reqs):
                print("Duplicate requirement in %s: %s" %
                      (self.name, str(req)))
                self.failed = True
            self.reqs[req.project_name.lower()] = req

    def read_all_requirements(self, global_req=False, include_dev=False,
                              strict=False):
        """ Read all the requirements into a list.

        Build ourselves a consolidated list of requirements. If global_req is
        True then we are parsing the global requirements file only, and
        ensure that we don't parse it's test-requirements.txt erroneously.

        If include_dev is true allow for development requirements, which
        may be prereleased versions of libraries that would otherwise be
        listed. This is most often used for oslo prereleases.

        If strict is True then style checks should be performed while reading
        the file.
        """
        if global_req:
            self.read_requirements('global-requirements.txt', strict=strict)
        else:
            for fn in ['tools/pip-requires',
                       'tools/test-requires',
                       'requirements.txt',
                       'test-requirements.txt'
                       ]:
                self.read_requirements(fn, strict=strict)
        if include_dev:
            self.read_requirements('dev-requirements.txt',
                                   ignore_dups=True, strict=strict)


def grab_args():
    """Grab and return arguments"""
    parser = argparse.ArgumentParser(
        description="Check if project requirements have changed"
    )
    parser.add_argument('--local', action='store_true',
                        help='check local changes (not yet in git)')
    parser.add_argument('branch', nargs='?', default='master',
                        help='target branch for diffs')
    parser.add_argument('--zc', help='what zuul cloner to call')

    return parser.parse_args()


@contextlib.contextmanager
def tempdir():
    try:
        reqroot = tempfile.mkdtemp()
        yield reqroot
    finally:
        shutil.rmtree(reqroot)


def main():
    args = grab_args()
    branch = args.branch

    # build a list of requirements in the proposed change,
    # and check them for style violations while doing so
    head = run_command("git rev-parse HEAD")[0]
    head_reqs = RequirementsList('HEAD')
    head_reqs.read_all_requirements(strict=True)

    branch_reqs = RequirementsList(branch)
    if not args.local:
        # build a list of requirements already in the target branch,
        # so that we can create a diff and identify what's being changed
        run_command("git remote update")
        run_command("git checkout remotes/origin/%s" % branch)
        branch_reqs.read_all_requirements()

        # switch back to the proposed change now
        run_command("git checkout %s" % head)

    # build a list of requirements from the global list in the
    # openstack/requirements project so we can match them to the changes
    with tempdir() as reqroot:
        reqdir = os.path.join(reqroot, "openstack/requirements")
        if args.zc is not None:
            zc = args.zc
        else:
            zc = '/usr/zuul-env/bin/zuul-cloner'
        out, err = run_command("%(zc)s "
                               "--cache-dir /opt/git "
                               "--workspace %(root)s "
                               "git://git.openstack.org "
                               "openstack/requirements"
                               % dict(zc=zc, root=reqroot))
        print out
        print err
        os.chdir(reqdir)
        print "requirements git sha: %s" % run_command(
            "git rev-parse HEAD")[0]
        os_reqs = RequirementsList('openstack/requirements')
        if branch == 'master' or branch.startswith('feature/'):
            include_dev = True
        else:
            include_dev = False
        os_reqs.read_all_requirements(include_dev=include_dev,
                                      global_req=True)

        # iterate through the changing entries and see if they match the global
        # equivalents we want enforced
        failed = False
        for req in head_reqs.reqs.values():
            name = req.project_name.lower()
            if name in branch_reqs.reqs and req == branch_reqs.reqs[name]:
                continue
            if name not in os_reqs.reqs:
                print(
                    "Requirement %s not in openstack/requirements" % str(req))
                failed = True
                continue
            # pkg_resources.Requirement implements __eq__() but not __ne__().
            # There is no implied relationship between __eq__() and __ne__()
            # so we must negate the result of == here instead of using !=.
            if not (req == os_reqs.reqs[name]):
                print("Requirement %s does not match openstack/requirements "
                      "value %s" % (str(req), str(os_reqs.reqs[name])))
                failed = True

    # report the results
    if failed or os_reqs.failed or head_reqs.failed or branch_reqs.failed:
        sys.exit(1)
    print("Updated requirements match openstack/requirements.")


if __name__ == '__main__':
    main()
