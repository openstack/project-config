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
    echo "VENV: The tox environment to run (eg 'py27')"
    exit 1
fi

script_path=/usr/local/jenkins/slave_scripts

oslo_libs="automaton"
oslo_libs="$oslo_libs debtcollector"
oslo_libs="$oslo_libs futurist"
oslo_libs="$oslo_libs oslo.cache"
oslo_libs="$oslo_libs oslo.concurrency"
oslo_libs="$oslo_libs oslo.config"
oslo_libs="$oslo_libs oslo.context"
oslo_libs="$oslo_libs oslo.db"
oslo_libs="$oslo_libs oslo.i18n"
oslo_libs="$oslo_libs oslo.log"
oslo_libs="$oslo_libs oslo.messaging"
oslo_libs="$oslo_libs oslo.middleware"
oslo_libs="$oslo_libs oslo.policy"
oslo_libs="$oslo_libs oslo.privsep"
oslo_libs="$oslo_libs oslo.reports"
oslo_libs="$oslo_libs oslo.rootwrap"
oslo_libs="$oslo_libs oslo.serialization"
oslo_libs="$oslo_libs oslo.service"
oslo_libs="$oslo_libs oslo.utils"
oslo_libs="$oslo_libs oslo.versionedobjects"
oslo_libs="$oslo_libs oslo.vmware"
oslo_libs="$oslo_libs oslosphinx"
oslo_libs="$oslo_libs oslotest"
oslo_libs="$oslo_libs taskflow"
oslo_libs="$oslo_libs tooz"
oslo_libs_count=$(echo $oslo_libs | awk '{print NF}')

# NOTE(dims): tox barfs when there are {posargs} references
# in the commands we reference
sed -ri 's/\{posargs\}//g' tox.ini

cat << EOF > oslo-from-master.sh
#!/bin/bash

echo "Installing $oslo_libs_count oslo libraries (from git), please wait..."
pip freeze > pip_freeze_before.txt
for lib in $oslo_libs; do
    pip install -q -U \
        -e git+https://git.openstack.org/openstack/\${lib}.git#egg=\${lib}
done
pip freeze > pip_freeze_after.txt

echo "Installed:"
for lib in $oslo_libs; do
    grep \${lib} pip_freeze_after.txt
done

echo "Full freeze diff:"

# Diff seems to exit with non-zero on a difference, but since
# we expect there to be a difference, we don't want to have this
# (or tox) fail due to that...
diff -u pip_freeze_before.txt pip_freeze_after.txt || true

EOF

chmod +x oslo-from-master.sh

# Use the explicit environment (if we can).
if grep "^\[testenv:${venv}\]" tox.ini; then
cat << EOF >> tox.ini

[testenv:${venv}-oslo-master]
posargs =
commands =
    bash oslo-from-master.sh
    {[testenv:${venv}]commands}
EOF
else
cat << EOF >> tox.ini

[testenv:${venv}-oslo-master]
commands =
    bash oslo-from-master.sh
    {[testenv]commands}
EOF
fi

echo "Post-modification tox.ini:"
cat tox.ini

$script_path/run-tox.sh $venv-oslo-master
