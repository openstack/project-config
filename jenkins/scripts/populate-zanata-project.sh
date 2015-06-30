#!/bin/bash -xe

# Copyright (c) 2015 Hewlett-Packard Development Company, L.P.
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

PROJECT=$1

source /usr/local/jenkins/slave_scripts/common_translation_update.sh

setup_translation
case "$PROJECT" in
    api-site|ha-guide|operations-guide|security-doc)
        init_manuals "$PROJECT"
        setup_manuals "$PROJECT"
        ;;
    django_openstack_auth)
        setup_django_openstack_auth
        ;;
    horizon)
        setup_horizon
        ;;
    *)
        setup_project "$PROJECT"
        ;;
esac

# Download all files from transifex
tx pull -a -f --minimum-perc=0

# And upload them to Zanata
zanata-cli -B -e push --push-type both

# Undo everything we did locally
git reset --hard
