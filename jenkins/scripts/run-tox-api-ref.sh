#!/bin/bash -xe

# If a bundle file is present, call tox with the jenkins version of
# the test environment so it is used.  Otherwise, use the normal
# (non-bundle) test environment.  Also, run pbr freeze on the
# resulting environment at the end so that we have a record of exactly
# what packages we ended up testing.
#
# Usage: run-tox-api-ref.sh API_REF_DIR
#
# Where VENV is the name of the tox environment to run (specified in the
# project's tox.ini file).

api_ref_dir=${1:-./os-api-ref}

script_path=/usr/local/jenkins/slave_scripts

# NOTE(tonyb): This assumes running in the gate and that the git setup has
# copied the upper-constraints.txt into a local file and set the
# UPPER_CONSTRAINTS_FILE appropriately.  The new commands will fail and cause
# job failures if these pre-conditions are not met.
cat <<EOF >> tox.ini
[testenv:api-ref-src]
deps =
    {[testenv]deps}
    openstack-requirements
commands =
    edit-constraints {env:UPPER_CONSTRAINTS_FILE:} -- os-api-ref
    pip install -c {env:UPPER_CONSTRAINTS_FILE:} $api_ref_dir
    sphinx-build -W -b html -d api-ref/build/doctrees api-ref/source api-ref/build/html
EOF

$script_path/run-tox.sh api-ref-src
