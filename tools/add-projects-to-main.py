#!/usr/bin/env python

# Copyright 2017 Red Hat, Inc.
#
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

import ruamel.yaml


def get_single_key(var):
    if isinstance(var, str):
        return var
    elif isinstance(var, list):
        return var[0]
    return list(var.keys())[0]


def get_comment_text(token):
    if token is None:
        return ''
    elif isinstance(token, list):
        text = ''
        for subtoken in token:
            if subtoken:
                text += get_comment_text(subtoken)
        return text
    else:
        return token.value


def add_projects():
    yaml = ruamel.yaml.YAML()
    yaml.indent(mapping=2, sequence=4, offset=2)
    all_projects = yaml.load(open('gerrit/projects.yaml', 'r'))
    zuul_main = yaml.load(open('zuul/main.yaml', 'r'))

    existing_projects = set()
    gerrit = None
    for tenant in zuul_main:
        if tenant['tenant']['name'] == 'openstack':
            gerrit = tenant['tenant']['source']['gerrit']
            break

    # Find the point in the list where we want to add things and save the
    # comment text from it so that we can re-add it
    sorted_index = None
    saved_comment = None
    for idx, token in gerrit['untrusted-projects'].ca.items.items():
        text = get_comment_text(token)
        if text.startswith('# After this point'):
            sorted_index = idx
            saved_comment = token
            break

    # Get the list of things above the marker comment
    for project_type in ('config-projects', 'untrusted-projects'):
        for idx, project in enumerate(gerrit[project_type]):
            if idx == sorted_index:
                break
            if isinstance(project, dict):
                project = get_single_key(project)
            existing_projects.add(project)

    new_projects = []
    for project in all_projects:
        name = project['project']
        # It's in the file, already - it's taken care of
        if name in existing_projects:
            continue

        # Skip or remove retired projects
        is_retired = name.split('/')[0].endswith('-attic')
        in_attic = project.get('acl-config', '').endswith('/retired.config')
        if is_retired or in_attic:
            if name in gerrit['untrusted-projects']:
                del gerrit['untrusted-projects'][name]
            continue

        new_projects.append(name)

    # Pop things off the end of the list until we're down at the length
    # indicated by the saved index position. We have to do this weirdly
    # with passing the index to pop because it's not a real list
    for idx in reversed(range(sorted_index,
                              len(gerrit['untrusted-projects']))):
        gerrit['untrusted-projects'].pop(idx)

    # Toss in a sorted just to make sure - the source list should be sorted
    # but why tempt fate right?
    gerrit['untrusted-projects'].extend(sorted(new_projects))
    gerrit['untrusted-projects'].ca.items[sorted_index] = saved_comment

    yaml.dump(zuul_main, open('zuul/main.yaml', 'w'))

    # Strip the extra 2 spaces that ruamel.yaml appends because we told it
    # to indent an extra 2 spaces. Because the top level entry is a list it
    # applies that indentation at the top. It doesn't indent the comment lines
    # extra though, so don't do them.
    with open('zuul/main.yaml', 'r') as main_in:
        main_content = main_in.readlines()
    with open('zuul/main.yaml', 'w') as main_out:
        for line in main_content:
            if '#' in line:
                main_out.write(line)
            else:
                main_out.write(line[2:])


def main():
    add_projects()


if __name__ == '__main__':
    main()
