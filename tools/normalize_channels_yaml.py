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

import locale
import sys
import yaml
from collections import OrderedDict
import projectconfig_yamllib as pcy


def main():
    locale.setlocale(locale.LC_COLLATE, 'C')

    yaml.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG,
                         pcy.construct_yaml_map)

    yaml.add_representer(OrderedDict, pcy.project_representer,
                         Dumper=pcy.IndentedDumper)

    chandata = yaml.load(open('gerritbot/channels.yaml'))
    for k, v in chandata.items():
        v['projects'] = sorted(v['projects'])

    sys.stdout.write('# This file is sorted alphabetically by channel name.\n')
    first = True
    for k in sorted(chandata.keys()):
        if not first:
            sys.stdout.write('\n')
        first = False
        sys.stdout.write(yaml.dump({k: chandata[k]}, default_flow_style=False,
                                   Dumper=pcy.IndentedDumper, width=80,
                                   indent=2))

if __name__ == '__main__':
    main()
