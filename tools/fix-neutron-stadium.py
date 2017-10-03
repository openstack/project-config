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

import collections
import subprocess

import ruamel.yaml
import yaml


# from :
# http://stackoverflow.com/questions/8640959/how-can-i-control-what-scalar-form-pyyaml-uses-for-my-data  flake8: noqa
def should_use_block(value):
    for c in u"\u000a\u000d\u001c\u001d\u001e\u0085\u2028\u2029":
        if c in value:
            return True
    return False


def my_represent_scalar(self, tag, value, style=None):
    if style is None:
        if should_use_block(value):
             style='|'
        else:
            style = self.default_style

    node = yaml.representer.ScalarNode(tag, value, style=style)
    if self.alias_key is not None:
        self.represented_objects[self.alias_key] = node
    return node

def project_representer(dumper, data):
    return dumper.represent_mapping('tag:yaml.org,2002:map',
                                    data.items())


def construct_yaml_map(self, node):
    data = collections.OrderedDict()
    yield data
    value = self.construct_mapping(node)

    if isinstance(node, yaml.MappingNode):
        self.flatten_mapping(node)
    else:
        raise yaml.constructor.ConstructorError(
            None, None,
            'expected a mapping node, but found %s' % node.id,
            node.start_mark)

    mapping = collections.OrderedDict()
    for key_node, value_node in node.value:
        key = self.construct_object(key_node, deep=False)
        try:
            hash(key)
        except TypeError as exc:
            raise yaml.constructor.ConstructorError(
                'while constructing a mapping', node.start_mark,
                'found unacceptable key (%s)' % exc, key_node.start_mark)
        value = self.construct_object(value_node, deep=False)
        mapping[key] = value
    data.update(mapping)


class IndentedEmitter(yaml.emitter.Emitter):
    def expect_block_sequence(self):
        self.increase_indent(flow=False, indentless=False)
        self.state = self.expect_first_block_sequence_item


class IndentedDumper(IndentedEmitter, yaml.serializer.Serializer,
                     yaml.representer.Representer, yaml.resolver.Resolver):
    def __init__(self, stream,
                 default_style=None, default_flow_style=None,
                 canonical=None, indent=None, width=None,
                 allow_unicode=None, line_break=None,
                 encoding=None, explicit_start=None, explicit_end=None,
                 version=None, tags=None):
        IndentedEmitter.__init__(
            self, stream, canonical=canonical,
            indent=indent, width=width,
            allow_unicode=allow_unicode,
            line_break=line_break)
        yaml.serializer.Serializer.__init__(
            self, encoding=encoding,
            explicit_start=explicit_start,
            explicit_end=explicit_end,
            version=version, tags=tags)
        yaml.representer.Representer.__init__(
            self, default_style=default_style,
            default_flow_style=default_flow_style)
        yaml.resolver.Resolver.__init__(self)


def ordered_load(stream, *args, **kwargs):
    yaml.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG,
                         construct_yaml_map)

    return yaml.load(stream=stream, *args, **kwargs)


def ordered_dump(data, stream=None, *args, **kwargs):
    dumper = IndentedDumper
    # We need to do this because of how template expasion into a project
    # works. Without it, we end up with YAML references to the expanded jobs.
    dumper.ignore_aliases = lambda self, data: True
    yaml.add_representer(collections.OrderedDict, project_representer,
                         Dumper=IndentedDumper)

    output = yaml.dump(
        data, default_flow_style=False,
        Dumper=dumper, width=80, *args, **kwargs).replace(
            '\n-', '\n\n-')
    if stream:
        stream.write(output)
    else:
        return output


def get_single_key(var):
    if isinstance(var, str):
        return var
    elif isinstance(var, list):
        return var[0]
    return list(var.keys())[0]


def has_single_key(var):
    if isinstance(var, list):
        return len(var) == 1
    if isinstance(var, str):
        return True
    dict_keys = list(var.keys())
    if len(dict_keys) != 1:
        return False
    if var[get_single_key(var)]:
        return False
    return True



def main():
    subprocess.run(['git', 'checkout', '--', 'zuul.d/projects.yaml'])
    yaml = ruamel.yaml.YAML()
    yaml.indent(mapping=2, sequence=4, offset=2)
    projects = yaml.load(open('zuul.d/projects.yaml', 'r'))

    for project in projects:
        if project['project']['name'].split('/')[1].startswith('networking-'):
            if 'templates' not in project['project']:
                continue
            templates = project['project']['templates']
            for template in ('openstack-python-jobs',
                             'openstack-python35-jobs'):
                if template in templates:
                    new_name = template + '-neutron'
                    templates[templates.index(template)] = new_name

    yaml.dump(projects, open('zuul.d/projects.yaml', 'w'))

    # Strip the extra 2 spaces that ruamel.yaml appends because we told it
    # to indent an extra 2 spaces. Because the top level entry is a list it
    # applies that indentation at the top. It doesn't indent the comment lines
    # extra though, so don't do them.
    with open('zuul.d/projects.yaml', 'r') as main_in:
        main_content = main_in.readlines()
    with open('zuul.d/projects.yaml', 'w') as main_out:
        for line in main_content:
            if '#' in line:
                main_out.write(line)
            else:
                if line.startswith('  - project'):
                    main_out.write('\n')
                main_out.write(line[2:])

if __name__ == '__main__':
    main()
