#!/bin/bash -xe

# If a bundle file is present, call tox with the jenkins version of
# the test environment so it is used.  Otherwise, use the normal
# (non-bundle) test environment.  Also, run pbr freeze on the
# resulting environment at the end so that we have a record of exactly
# what packages we ended up testing.
#

venv=venv

VDISPLAY=99
DIMENSIONS='1280x1024x24'
/usr/bin/Xvfb :${VDISPLAY} -screen 0 ${DIMENSIONS} 2>&1 > /dev/null &

set +e
DISPLAY=:${VDISPLAY} NOSE_WITH_XUNIT=1 tox -e$venv -- \
    /bin/bash run_tests.sh -N --only-selenium
result=$?

pkill Xvfb 2>&1 > /dev/null
set -e

[ -e .tox/$venv/bin/pbr ] && freezecmd=pbr || freezecmd=pip

echo "Begin $freezecmd freeze output from test virtualenv:"
echo "======================================================================"
.tox/${venv}/bin/${freezecmd} freeze
echo "======================================================================"

exit $result
