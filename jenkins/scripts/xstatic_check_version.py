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

import importlib
import os
import sys

from setuptools_scm import get_version

# add the xstatic repos checkout to the PYTHONPATH so we can
# import its contents
sys.path.append(os.getcwd())

xs = None
for name in os.listdir('xstatic/pkg'):
    if os.path.isdir('xstatic/pkg/' + name):
        if xs is not None:
            sys.exit('More than one xstatic.pkg package found.')
        xs = importlib.import_module('xstatic.pkg.' + name)

if xs is None:
    sys.exit('No xstatic.pkg package found.')

git_version = get_version()
if git_version != xs.PACKAGE_VERSION:
    sys.exit('git tag version ({}) does not match package version ({})'.
             format(git_version, xs.PACKAGE_VERSION))
