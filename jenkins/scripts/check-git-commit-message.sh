#!/bin/bash -xe

# Copyright 2015 Rackspace Australia
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

# Check the commit message at HEAD for style


CHECK_SUBJECT_LENGTH=${CHECK_SUBJECT_LENGTH:-0}
CHECK_DOCIMPACT_STRING=${CHECK_DOCIMPACT_STRING:-1}
COMMIT=${COMMIT:-HEAD}

function check_subject_length {
    # Checks that the subject (first line of the commit message) is less than
    # the max-length

    # $1 message
    # $2 max-length

    # TODO(jhesketh) if this is a thing we want
    echo "check_subject_length not implemented"
    exit 1
}


function check_docimpact_string {
    # Checks there is a description following the DocImpact tag as per
    # http://specs.openstack.org/openstack/docs-specs/specs/mitaka/review-docimpact.html

    # $1 message

    # Check if there is a line starting with DocImpact (case-insensitive).
    # If there is, then check it's in the correct format (case-sensitive).
    echo "$1" | grep -qi "^DocImpact"
    if [ $? -eq 0 ]; then
        echo "$1" | grep -q "^DocImpact\: .*$"
        if [ $? -ne 0 ]; then
            echo "DocImpact must have a description following it."
            exit 1
        fi
    fi
}


# Grab the message
message="$(git log --format=%B -n 1 $COMMIT)"

if [ $CHECK_SUBJECT_LENGTH -gt 0 ]; then
    check_subject_length "$message" $CHECK_SUBJECT_LENGTH
fi

if [ $CHECK_DOCIMPACT_STRING -gt 0 ]; then
    check_docimpact_string "$message"
fi
