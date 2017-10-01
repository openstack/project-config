#!/bin/bash -xe

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

# Install all known OpenStackClient projects that have plugins. Then install
# the proposed change to see if there are any conflicting commands.

# install openstackclient plugins from source to catch conflicts earlier
function install_from_source {
    repo=$1
    root=$(mktemp -d)
    $zc --cache-dir /opt/git --workspace ${root} \
        git://git.openstack.org openstack/${repo}
    (cd ${root}/openstack/${repo} && $venv/bin/pip install .)
    rm -rf $root
}

zc='/usr/zuul-env/bin/zuul-cloner'

# setup a virtual environment to install all the plugins
venv_name='osc_plugins'
trap "rm -rf $venv_name" EXIT
virtualenv $venv_name
venv=$(pwd)/$venv_name

# install known OpenStackClient plugins
install_from_source python-openstackclient
install_from_source python-barbicanclient
install_from_source python-cloudkittyclient
install_from_source python-congressclient
install_from_source python-designateclient
install_from_source python-heatclient
install_from_source python-ironicclient
install_from_source python-ironic-inspector-client
install_from_source python-karborclient
install_from_source python-mistralclient
install_from_source python-muranoclient
install_from_source python-neutronclient
install_from_source python-octaviaclient
install_from_source python-pankoclient
install_from_source python-saharaclient
install_from_source python-searchlightclient
install_from_source python-senlinclient
install_from_source python-tripleoclient
install_from_source python-troveclient
install_from_source python-vitrageclient
install_from_source python-watcherclient
install_from_source python-zaqarclient

echo "Begin freeze output from $venv virtualenv:"
echo "======================================================================"
$venv/bin/pip freeze
echo "======================================================================"

# now check the current proposed change doesn't cause a conflict
# we should already be in the project's root directory where setup.py exists
echo "Installing the proposed change in directory: $(pwd)"
$venv/bin/pip install -e .

echo "Testing development version of openstack client, version:"
$venv/bin/openstack --version

# run the python script to actually check the commands now that we're setup
$venv/bin/python /usr/local/jenkins/slave_scripts/check_osc_commands.py
