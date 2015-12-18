#! /usr/bin/env python
#
# Copyright (c) 2015 Hewlett-Packard Development Company, L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import yaml
import requests
from collections import OrderedDict
import requestsexceptions

def project_representer(dumper, data):
    return dumper.represent_mapping('tag:yaml.org,2002:map',
                                    data.items())


def construct_yaml_map(self, node):
    data = OrderedDict()
    yield data
    value = self.construct_mapping(node)

    if isinstance(node, yaml.MappingNode):
        self.flatten_mapping(node)
    else:
        raise yaml.constructor.ConstructorError(
            None, None,
            'expected a mapping node, but found %s' % node.id,
            node.start_mark)

    mapping = OrderedDict()
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


def main():
    requestsexceptions.squelch_warnings()
    yaml.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG,
                         construct_yaml_map)

    yaml.add_representer(OrderedDict, project_representer,
                         Dumper=IndentedDumper)

    data = yaml.load(open('openstack_catalog/web/static/assets.yaml'))

    assets = []
    for a in data['assets']:
        if not a.get('attributes', {}).get('active', True):
            assets.append(a)
            continue
        url = a.get('attributes', {}).get('url')
        if url:
            r = requests.head(url, allow_redirects=True)
            if r.status_code != 200:
                a['attributes']['active'] = False
        assets.append(a)

    output = {'assets': assets}
    with open('openstack_catalog/web/static/assets.yaml', 'w') as out:
        out.write(yaml.dump(output, default_flow_style=False,
                            Dumper=IndentedDumper, width=80,
                            indent=2))

if __name__ == '__main__':
    main()
