#! /usr/bin/env python3
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

import projectconfig_ruamellib as yaml


def main():

    data = yaml.load(open('gerrit/projects.yaml'))

    for project in data:
        if 'upstream' in project:
            del project['upstream']

    with open('gerrit/projects.yaml', 'w') as out:
        yaml.dump(data, stream=out)


if __name__ == '__main__':
    main()
