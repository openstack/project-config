#!/bin/bash

# Copyright 2012 Hewlett-Packard Development Company, L.P.
# Copyright 2013 OpenStack Foundation
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

# Find out if zuul has attempted to run any sudo commands by checking
# the auth.log or secure log or messages files before and after a test run.

PATTERN="sudo.*zuul.*:.*\(incorrect password attempts\|command not allowed\)"
if [ -f /var/log/auth.log ]; then
    OLDLOGFILE=/var/log/auth.log.1
    LOGFILE=/var/log/auth.log
elif [ -f /var/log/secure ]; then
    OLDLOGFILE=$( ls /var/log/secure-* | sort | tail -n1 )
    LOGFILE=/var/log/secure
elif [ -f /var/log/messages ]; then
    OLDLOGFILE=$( ls /var/log/messages-* | sort | tail -n1 )
    LOGFILE=/var/log/messages
else
    echo "*** Could not find auth.log/secure/messages log for sudo tracing"
    exit 1
fi

case "$1" in
    pre)
        rm -fr /tmp/zuul-sudo-log
        mkdir /tmp/zuul-sudo-log
        if [ -f "$OLDLOGFILE" ]; then
            stat -c %Y $OLDLOGFILE > /tmp/zuul-sudo-log/mtime-pre
        else
            echo "0" > /tmp/zuul-sudo-log/mtime-pre
        fi
        grep -h "$PATTERN" $LOGFILE > /tmp/zuul-sudo-log/pre
        exit 0
        ;;
    post)
        if [ -f "$OLDLOGFILE" ]; then
            stat -c %Y $OLDLOGFILE > /tmp/zuul-sudo-log/mtime-post
        else
            echo "0" > /tmp/zuul-sudo-log/mtime-post
        fi
        if ! diff /tmp/zuul-sudo-log/mtime-pre /tmp/zuul-sudo-log/mtime-post > /dev/null; then
            echo "diff"
            grep -h "$PATTERN" $OLDLOGFILE > /tmp/zuul-sudo-log/post
        fi
        grep -h "$PATTERN" $LOGFILE >> /tmp/zuul-sudo-log/post
        diff /tmp/zuul-sudo-log/pre /tmp/zuul-sudo-log/post
        ;;
esac
