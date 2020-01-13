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
import projectconfig_ruamellib as yaml


def main():
    locale.setlocale(locale.LC_COLLATE, 'C')

    chandata = yaml.load(open('gerritbot/channels.yaml'))

    for k, v in chandata.items():
        v['projects'] = sorted(v['projects'])

    yaml.dump(chandata, stream=sys.stdout)


if __name__ == '__main__':
    main()
