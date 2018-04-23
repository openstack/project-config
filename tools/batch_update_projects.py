#!/usr/bin/env python

# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

import os

import git
from projectconfig_ruamellib import YAML  # noqa


GIT_DIR = '~/git'
LOG = open('/tmp/log', 'w')
SCRIPT = open('/tmp/script', 'w')

TOPIC = "zuulv3-FIXME"
MSG = """Zuul: FIXME

FIXME
"""


def log(x):
    print(x)
    LOG.write(x + '\n')


def script(x):
    SCRIPT.write(x + '\n')


def handle_file(path, config_path):
    log('    File: %s' % config_path)
    yaml = YAML()
    try:
        config = yaml.load(open(config_path))
    except Exception:
        log("      Has yaml errors")
        return
    if not config:
        log("      No config")
        return
    updated = False
    for block in config:
        # FIXME: Perform the transformation here, if changed, set updated
        updated = True
    if updated:
        log("      Updated")
        with open(config_path, 'w') as f:
            yaml.dump(config, f)
        return True
    return False


def handle_branch(path):
    updated = []
    for fn in ['zuul.yaml', '.zuul.yaml']:
        if os.path.exists(os.path.join(path, fn)):
            if handle_file(path, os.path.join(path, fn)):
                updated.append(os.path.join(path, fn))
    for dfn in ['zuul.d', '.zuul.d']:
        zuul_path = os.path.join(path, dfn)
        if os.path.exists(zuul_path):
            for root, dirs, files in os.walk(zuul_path):
                for fn in files:
                    if fn.startswith('.nfs'):
                        continue
                    if handle_file(path, os.path.join(root, fn)):
                        updated.append(os.path.join(root, fn))
    return updated


def handle_repo(path):
    log('Repo: %s' % path)
    repo = git.Repo(path)
    repo.git.fetch('origin', tags=True)
    origin = repo.remotes['origin']
    for ref in origin.refs:
        x, branch = ref.name.split('/', 1)
        if branch == 'HEAD':
            continue
        log('  Branch: %s' % branch)
        repo.git.checkout(branch)
        repo.git.reset('--hard', 'remotes/origin/' + branch)
        for files in os.listdir(path):
            if not ('zuul.yaml' in files or '.zuul.yaml' in files or
                    'zuul.d' in files or '.zuul.d' in files):
                continue
        files = handle_branch(path)
        if files:
            repo.index.add(files)
            repo.index.commit(MSG)
            script('cd %s' % path)
            script('git checkout %s' % branch)
            script('git review -t %s' % TOPIC)


def main():
    for root in os.listdir(GIT_DIR):
        # TODO: ignore read-only repos
        if root.startswith('deb-'):
            continue
        path = os.path.join(GIT_DIR, root)
        if not os.path.isdir(path):
            continue
        handle_repo(path)


if __name__ == '__main__':
    log("Start")
    main()
    log("End")
