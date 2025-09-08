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

import ruamel.yaml


def none_representer(dumper, data):
    return dumper.represent_scalar('tag:yaml.org,2002:null', 'null')


class YAML(object):
    def __init__(self):
        """Wrap construction of ruamel yaml object."""
        self.yaml = ruamel.yaml.YAML()
        self.yaml.allow_duplicate_keys = True
        self.yaml.representer.add_representer(type(None), none_representer)
        self.yaml.indent(mapping=2, sequence=4, offset=2)

    def load(self, stream):
        return self.yaml.load(stream)

    def tr(self, x):
        x = x.replace('\n-', '\n\n-')
        newlines = []
        for line in x.split('\n'):
            if '#' in line:
                newlines.append(line.rstrip())
            else:
                newlines.append(line[2:].rstrip())
        return '\n'.join(newlines)

    def dump(self, data, *args, **kwargs):
        if isinstance(data, list):
            kwargs['transform'] = self.tr
        self.yaml.dump(data, *args, **kwargs)


_yaml = YAML()


def load(*args, **kwargs):
    return _yaml.load(*args, **kwargs)


def dump(*args, **kwargs):
    return _yaml.dump(*args, **kwargs)
