#!/usr/bin/env python
#
# Add a comment on a number of Launchpad bugs
#
# Copyright 2015 Thierry Carrez <thierry@openstack.org>
# All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

import argparse
import os
import re

import launchpadlib.launchpad
import lazr.restfulclient.errors


def main():
    # Parameters
    parser = argparse.ArgumentParser(description="Add comment on bugs")
    parser.add_argument('--subject', help='The comment subject',
                        default='Comment added by add_comment')
    parser.add_argument('--content', help='The comment content',
                        default='Comment added by add_comment')
    parser.add_argument('--series', help='The series being released. Will set '
                        'the bug status to Fix Released when specified')
    lp_grp = parser.add_argument_group('launchpad')
    lp_grp.add_argument(
        "--test",
        action='store_const',
        dest='lp_service_root',
        const='staging',
        default='production',
        help='Use LP staging server to test',
    )
    lp_grp.add_argument(
        '--credentials-file', '-c',
        dest='lp_creds_file',
        default=os.environ.get('LP_CREDS_FILE'),
        help=('plain-text credentials file, '
              'defaults to value of $LP_CREDS_FILE'),
    )
    parser.add_argument('bugs', type=int, nargs='+',
                        help='Bugs to add comment to')
    args = parser.parse_args()

    # Connect to Launchpad
    print(
        "Connecting to Launchpad at {!r} using credentials in {!r}...".format(
            args.lp_service_root,
            args.lp_creds_file)
    )
    launchpad = launchpadlib.launchpad.Launchpad.login_with(
        application_name='openstack-releasing',
        service_root=args.lp_service_root,
        credentials_file=args.lp_creds_file,
    )

    # Add comment and optionally set status to "Fix Released"
    for bugid in args.bugs:
        print("Adding comment to #%d..." % bugid, end='')
        try:
            bug = launchpad.bugs[bugid]
            bug.newMessage(subject=args.subject, content=args.content)
            print(" done.")
        except lazr.restfulclient.errors.ServerError:
            print(" TIMEOUT during save !")
        except Exception as e:
            print(" ERROR during save ! (%s)" % e)

        # Skip setting the bug status if --series was not specified
        if not args.series:
            continue

        print("Setting #%d to 'Fix Released' on %s..." % (bugid, args.series),
              end='')
        try:
            bug = launchpad.bugs[bugid]
            for task in bug.bug_tasks:
                # Find '\bSERIES$' in the bug_target_name
                if re.findall(r'\b%s$' % args.series, task.bug_target_name):
                    task.status = "Fix Released"
                    task.lp_save()
                    print(" done.")
                    break
        except lazr.restfulclient.errors.ServerError:
            print(" TIMEOUT during save !")
        except Exception as e:
            print(" ERROR during save ! (%s)" % e)


if __name__ == '__main__':
    main()
