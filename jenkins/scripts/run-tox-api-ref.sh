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

cat <<EOF >> tox.ini
[testenv:api-ref-src]
commands =
    pip install -U $api_ref_dir
    sphinx-build -W -b html -d api-ref/build/doctrees api-ref/source api-ref/build/html
EOF

$script_path/run-tox.sh api-ref-src
