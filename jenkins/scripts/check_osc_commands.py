#! /usr/bin/env python
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

"""
This module will use `pkg_resources` to scan commands for all OpenStackClient
plugins with the purpose of detecting duplicate commands.
"""

import pkg_resources


def find_duplicates():
    """Find duplicates commands.

    Here we use `pkg_resources` to find all modules. There will be many modules
    on a system, so we filter them out based on "openstack" since that is the
    prefix that OpenStackClient plugins will have.

    Each module has various entry points, each OpenStackClient command will
    have an entrypoint. Each entry point has a short name (ep.name) which
    is the command the user types, as well as a long name (ep.module_name)
    which indicates from which module the entry point is from.

    For example, the entry point and module for v3 user list is::

        module => openstackclient.identity.v3
        ep.name => user_list
        ep.module_name =>  openstackclient.identity.v3.user

    We keep a running tally of valid commands, duplicate commands and commands
    that failed to load.

    The resultant data structure for valid commands should look like::

        {'user_list':
            ['openstackclient.identity.v3.user',
             'openstackclient.identity.v2.0.user']
         'flavor_list':
            [openstackclient.compute.v2.flavor']
        }

    The same can be said for the duplicate and failed commands.
    """

    valid_cmds = {}
    duplicate_cmds = {}
    failed_cmds = {}

    # find all modules on the system
    modules = set()
    for dist in pkg_resources.working_set:
        entry_map = pkg_resources.get_entry_map(dist)
        modules.update(set(entry_map.keys()))

    for module in modules:
        # OpenStackClient plugins are prefixed with "openstack", skip otherwise
        if not module.startswith('openstack'):
            continue

        # Iterate over all entry points
        for ep in pkg_resources.iter_entry_points(module):

            # cliff does a mapping between spaces and underscores
            ep_name = ep.name.replace(' ', '_')

            try:
                ep.load()
            except Exception:
                failed_cmds.setdefault(ep_name, []).append(ep.module_name)

            if _is_valid_command(ep_name, ep.module_name, valid_cmds):
                valid_cmds.setdefault(ep_name, []).append(ep.module_name)
            else:
                duplicate_cmds.setdefault(ep_name, []).append(ep.module_name)

    if duplicate_cmds:
        print("Duplicate commands found...")
        print(duplicate_cmds)
        return True
    if failed_cmds:
        print("Some commands failed to load...")
        print(failed_cmds)
        return True

    # Safely return False here with the full set of commands
    print("Final set of commands...")
    print(valid_cmds)
    print("Found no duplicate commands, OK to merge!")
    return False


def _is_valid_command(ep_name, ep_module_name, valid_cmds):
    """Determine if the entry point is valid.

    Aside from a simple check to see if the entry point short name is in our
    tally, we also need to check for allowed duplicates. For instance, in the
    case of supporting multiple versions, then we want to allow for duplicate
    commands. Both the identity v2 and v3 APIs support `user_list`, so these
    are fine.

    In order to determine if an entry point is a true duplicate we can check to
    see if the module name roughly matches the module name of the entry point
    that was initially added to the set of valid commands.

    The following should trigger a match::

        openstackclient.identity.v3.user and openstackclient.identity.v*.user

    Whereas, the following should fail::

        openstackclient.identity.v3.user and openstackclient.baremetal.v3.user

    """

    if ep_name not in valid_cmds:
        return True
    else:
        # there already exists an entry in the dictionary for the command...
        module_parts = ep_module_name.split(".")
        for valid_module_name in valid_cmds[ep_name]:
            valid_module_parts = valid_module_name.split(".")
            if (module_parts[0] == valid_module_parts[0] and
                    module_parts[1] == valid_module_parts[1] and
                    module_parts[3] == valid_module_parts[3]):
                    return True
    return False


if __name__ == '__main__':
    print("Checking 'openstack' plug-ins")
    if find_duplicates():
        exit(1)
    else:
        exit(0)
