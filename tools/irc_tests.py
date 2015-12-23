#! /usr/bin/env python

# Copyright 2015 SUSE Linux GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import sys
import yaml


def access_gerrit_check():
    "Check that all channels in gerritbot are in accessbot as well."

    errors = False

    access_config = yaml.load(open('accessbot/channels.yaml', 'r'))

    access_channels = []
    for channel in access_config['channels']:
        access_channels.append(channel['name'])

    access_channel_set = set(access_channels)

    gerrit_config = yaml.load(open('gerritbot/channels.yaml'))

    print("Basic check of gerritbot/channels.yaml")
    REQUIRED_ENTRIES=("branches", "events", "projects")
    VALID_EVENTS=("change-merged", "patchset-created", "x-vrif-minus-2")
    for channel in gerrit_config:
        for entry in REQUIRED_ENTRIES:
            if entry not in gerrit_config[channel]:
                print("  Required entry '%s' not specified for channel '%s'"
                      % (entry, channel))
                errors = True
            elif not gerrit_config[channel][entry]:
                print("  Entry '%s' has no content for channel '%s'"
                      % (entry, channel))
                errors = True

        for event in gerrit_config[channel]['events']:
            if event not in VALID_EVENTS:
                print("  Event '%s' for channel '%s' is invalid"
                      % (event, channel))
                errors = True

    print("\nChecking that all channels in gerritbot are also in accessbot")
    for channel in gerrit_config:
        if channel not in access_channel_set:
            print("  %s is missing from accessbot" % channel)
            errors = True

    return errors


def main():
    errors = access_gerrit_check()

    if errors:
        print("Found errors in channel setup!")
    else:
        print("No errors found in channel setup!")
    return errors

if __name__ == "__main__":
    sys.exit(main())
