#!/bin/bash -xe

# inspired from sister script run-tox-with-oslo-master.sh

project=$1
venv=$2

if [[ -z "$venv" || -z "$project" ]]; then
    echo "Usage: $?"
    echo
    echo "PROJECT: The openstack project run as master (eg 'neutron-lib')"
    echo "VENV: The tox environment to run (eg 'py35')"
    exit 1
fi

script_path=/usr/local/jenkins/slave_scripts

sed -i "s/${project}.*/-e git+https:\/\/git.openstack.org\/openstack\/${project}.git#egg=${project}/g" requirements.txt
sed -i "s/${project}.*/-e git+https:\/\/git.openstack.org\/openstack\/${project}.git#egg=${project}/g" upper-constraints.txt

$script_path/run-tox.sh $venv
