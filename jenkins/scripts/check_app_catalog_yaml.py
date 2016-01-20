#!/usr/bin/env python
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

import requests
import requestsexceptions
import yaml


def main():
    requestsexceptions.squelch_warnings()
    data = yaml.load(open('openstack_catalog/web/static/assets.yaml'))

    assets = {}
    for a in data['assets']:
        url = a.get('attributes', {}).get('url')
        if url:
            r = requests.head(url, allow_redirects=True)
            if r.status_code != 200:
                assets[a['name']] = {'active': False}

    with open('openstack_catalog/web/static/assets_dead.yaml', 'w') as out:
        out.write(yaml.safe_dump({"assets": assets}))


if __name__ == '__main__':
    main()
