#!/bin/bash -x

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

venv=${1:-pep8}

export UPPER_CONSTRAINTS_FILE=$(pwd)/upper-constraints.txt

python setup.py sdist
sdistrc=$?

tox -v -e$venv
rc=$?

[ -e .tox/$venv/bin/pbr ] && freezecmd=pbr || freezecmd=pip

echo "Begin $freezecmd freeze output from test virtualenv:"
echo "======================================================================"
.tox/${venv}/bin/${freezecmd} freeze
echo "======================================================================"

if [ ! $sdistrc ] ; then
    echo "******************************************************************"
    echo "Project cannot create sdist tarball!!!"
    echo "To reproduce this locally, run: 'python setup.py sdist'"
    echo "******************************************************************"
    exit $sdistrc
fi

exit $rc
