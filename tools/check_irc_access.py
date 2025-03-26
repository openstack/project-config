#! /usr/bin/env python3

# Copyright 2011, 2013-2014 OpenStack Foundation
# Copyright 2012 Hewlett-Packard Development Company, L.P.
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

import argparse
import functools
import irc.client
import logging
import random
import string
import ssl
import sys
import time
import yaml


logging.basicConfig(level=logging.INFO)


class CheckAccess(irc.client.SimpleIRCClient):
    log = logging.getLogger("checkaccess")

    def __init__(self, channels, nick, flags):
        irc.client.SimpleIRCClient.__init__(self)
        self.channels = channels
        self.nick = nick
        self.flags = flags
        self.current_channel = None
        self.current_list = []
        self.failed = None

    def on_disconnect(self, connection, event):
        if self.failed is not False:
            sys.exit(1)
        else:
            sys.exit(0)

    def on_welcome(self, c, e):
        self.advance()

    def on_privnotice(self, c, e):
        msg = e.arguments[0]
        self.advance(msg)

    def advance(self, msg=None):
        if not self.current_channel:
            if not self.channels:
                self.connection.quit()
                return
            self.current_channel = self.channels.pop()
            self.current_list = []
            self.connection.privmsg('chanserv', 'access %s list' %
                                    self.current_channel)
            time.sleep(1)
            return
        if not msg:
            return
        if msg.endswith('is not registered with channel services.'):
            self.failed = True
            print("%s is not registered with ChanServ." %
                  self.current_channel)
            self.current_channel = None
            self.advance()
            return
        if msg.endswith('not authorized to perform this operation.'):
            self.failed = True
            print("%s can not be queried from ChanServ." %
                  self.current_channel)
            self.current_channel = None
            self.advance()
            return
        if msg.startswith('End of'):
            found = False
            for nick, flags, msg in self.current_list:
                if nick == self.nick and flags == self.flags:
                    self.log.info('%s access ok on %s' %
                                  (self.nick, self.current_channel))
                    found = True
                    break
            if not found:
                self.failed = True
                print("%s does not have permissions on %s:" %
                      (self.nick, self.current_channel))
                for nick, flags, msg in self.current_list:
                    print(msg)
                print
            # If this is the first channel checked, set the failure
            # flag to false because we know that the system is
            # operating well enough to check at least one channel.
            if self.failed is None:
                self.failed = False
            self.current_channel = None
            self.advance()
            return
        parts = msg.split()
        self.current_list.append((parts[1], parts[2], msg))


def main():
    parser = argparse.ArgumentParser(description='IRC channel access check')
    parser.add_argument('-l', dest='config',
                        default='/etc/accessbot/channels.yaml',
                        help='path to the config file')
    parser.add_argument('-s', dest='server',
                        default='irc.oftc.net',
                        help='IRC server')
    parser.add_argument('-p', dest='port',
                        default=6697,
                        help='IRC port')
    parser.add_argument('nick',
                        help='the nick for which access should be validated')
    args = parser.parse_args()

    config = yaml.safe_load(open(args.config))
    channels = []
    for channel in config['channels']:
        channels.append('#' + channel['name'])

    access_level = None
    for level, names in config['global'].items():
        if args.nick in names:
            access_level = level
    if access_level is None:
        raise Exception("Unable to determine global access level for %s" %
                        args.nick)
    flags = config['access'][access_level]

    a = CheckAccess(channels, args.nick, flags)
    mynick = ''.join(random.choice(string.ascii_uppercase)
                     for x in range(16))
    port = int(args.port)
    if port == 6697:
        # Taken from the example in the Factory class docstring at
        # https://github.com/jaraco/irc/blob/main/irc/connection.py
        context = ssl.create_default_context()
        wrapper = functools.partial(
            context.wrap_socket, server_hostname=args.server)
        factory = irc.connection.Factory(wrapper=wrapper)
        a.connect(args.server, int(args.port), mynick,
                  connect_factory=factory)
    else:
        a.connect(args.server, int(args.port), mynick)
    a.start()


if __name__ == "__main__":
    main()
