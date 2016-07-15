#!/bin/bash -xe

# inspired from sister script run-tox-with-oslo-master.sh

venv=$1

if [[ -z "$venv" ]]; then
    echo "Usage: $?"
    echo
    echo "VENV: The tox environment to run (eg 'py34')"
    exit 1
fi

script_path=/usr/local/jenkins/slave_scripts

sed -i "s/neutron-lib.*/-e git+https:\/\/git.openstack.org\/openstack\/neutron-lib.git#egg=neutron-lib/g" requirements.txt

cat << EOF >> tox.ini

[testenv:py34-neutron-lib-master]
setenv = VIRTUAL_ENV={envdir}
passenv = TRACE_FAILONLY GENERATE_HASHES http_proxy HTTP_PROXY https_proxy HTTPS_PROXY no_proxy NO_PROXY
usedevelop = True
install_command = pip install {opts} {packages}
deps = -r{toxinidir}/requirements.txt
       -r{toxinidir}/test-requirements.txt
whitelist_externals = sh
commands =
  {toxinidir}/tools/ostestr_compat_shim.sh {posargs}
EOF

$script_path/run-tox.sh $venv-neutron-lib-master
