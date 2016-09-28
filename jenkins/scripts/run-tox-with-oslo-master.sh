#!/bin/bash -xe

# If a bundle file is present, call tox with the jenkins version of
# the test environment so it is used.  Otherwise, use the normal
# (non-bundle) test environment.  Also, run pbr freeze on the
# resulting environment at the end so that we have a record of exactly
# what packages we ended up testing.
#
# Usage: run-tox.sh VENV
#
# Where VENV is the name of the tox environment to run (specified in the
# project's tox.ini file).

venv=$1

if [[ -z "$venv" ]]; then
    echo "Usage: $?"
    echo
    echo "VENV: The tox environment to run (eg 'python27')"
    exit 1
fi

script_path=/usr/local/jenkins/slave_scripts

cat << EOF > oslo-from-master.sh
pip install -q -U \
    -e git+https://git.openstack.org/openstack/automaton.git#egg=automaton
pip install -q -U \
    -e git+https://git.openstack.org/openstack/debtcollector.git#egg=debtcollector
pip install -q -U \
    -e git+https://git.openstack.org/openstack/futurist.git#egg=futurist
pip install -q -U \
    -e git+https://git.openstack.org/openstack/oslo.cache.git#egg=oslo.cache
pip install -q -U \
    -e git+https://git.openstack.org/openstack/oslo.concurrency.git#egg=oslo.concurrency
pip install -q -U \
    -e git+https://git.openstack.org/openstack/oslo.config.git#egg=oslo.config
pip install -q -U \
    -e git+https://git.openstack.org/openstack/oslo.context.git#egg=oslo.context
pip install -q -U \
    -e git+https://git.openstack.org/openstack/oslo.i18n.git#egg=oslo.i18n
pip install -q -U \
    -e git+https://git.openstack.org/openstack/oslo.log.git#egg=oslo.log
pip install -q -U \
    -e git+https://git.openstack.org/openstack/oslo.messaging.git#egg=oslo.messaging
pip install -q -U \
    -e git+https://git.openstack.org/openstack/oslo.middleware.git#egg=oslo.middleware
pip install -q -U \
    -e git+https://git.openstack.org/openstack/oslo.policy.git#egg=oslo.policy
pip install -q -U \
    -e git+https://git.openstack.org/openstack/oslo.privsep.git#egg=oslo.privsep
pip install -q -U \
    -e git+https://git.openstack.org/openstack/oslo.reports.git#egg=oslo.reports
pip install -q -U \
    -e git+https://git.openstack.org/openstack/oslo.rootwrap.git#egg=oslo.rootwrap
pip install -q -U \
    -e git+https://git.openstack.org/openstack/oslo.serialization.git#egg=oslo.serialization
pip install -q -U \
    -e git+https://git.openstack.org/openstack/oslo.service.git#egg=oslo.service
pip install -q -U \
    -e git+https://git.openstack.org/openstack/oslo.utils.git#egg=oslo.utils
pip install -q -U \
    -e git+https://git.openstack.org/openstack/oslo.versionedobjects.git#egg=oslo.versionedobjects
pip install -q -U \
    -e git+https://git.openstack.org/openstack/oslo.vmware.git#egg=oslo.vmware
pip install -q -U \
    -e git+https://git.openstack.org/openstack/oslosphinx.git#egg=oslosphinx
pip install -q -U \
    -e git+https://git.openstack.org/openstack/oslotest.git#egg=oslotest
pip install -q -U \
    -e git+https://git.openstack.org/openstack/oslo.db.git#egg=oslo.db
pip install -q -U \
    -e git+https://git.openstack.org/openstack/taskflow.git#egg=taskflow
pip install -q -U \
    -e git+https://git.openstack.org/openstack/tooz.git#egg=tooz
pip freeze | grep oslo
EOF

# NOTE(dims): tox barfs when there are {posargs} references
# in the commands we reference
sed -ri 's/\{posargs\}//g' tox.ini

cat << EOF >> tox.ini

[testenv:py27-oslo-master]
commands =
    bash oslo-from-master.sh
    {[testenv]commands}
EOF

if grep "^\[testenv:py35\]" tox.ini
then
cat << EOF >> tox.ini

[testenv:py35-oslo-master]
posargs =
commands =
    bash oslo-from-master.sh
    {[testenv:py35]commands}
EOF
else
cat << EOF >> tox.ini

[testenv:py35-oslo-master]
posargs =
commands =
    bash oslo-from-master.sh
    {[testenv]commands}
EOF
fi

$script_path/run-tox.sh $venv-oslo-master
