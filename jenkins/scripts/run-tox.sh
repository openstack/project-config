#!/bin/bash -x

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

export NOSE_WITH_XUNIT=1
export NOSE_WITH_HTML_OUTPUT=1
export NOSE_HTML_OUT_FILE='nose_results.html'
export TMPDIR=`/bin/mktemp -d`
trap "rm -rf $TMPDIR" EXIT

cat /etc/image-hostname.txt

/usr/local/jenkins/slave_scripts/jenkins-oom-grep.sh pre

sudo /usr/local/jenkins/slave_scripts/jenkins-sudo-grep.sh pre

tox -v -e$venv
result=$?
[ -e .tox/$venv/bin/pbr ] && freezecmd=pbr || freezecmd=pip

echo "Begin $freezecmd freeze output from test virtualenv:"
echo "======================================================================"
.tox/${venv}/bin/${freezecmd} freeze
echo "======================================================================"

if [ -d ".testrepository" ] ; then
    if [ -f ".testrepository/0.2" ] ; then
        cp .testrepository/0.2 ./subunit_log.txt
    elif [ -f ".testrepository/0" ] ; then
        .tox/$venv/bin/subunit-1to2 < .testrepository/0 > ./subunit_log.txt
    fi
    .tox/$venv/bin/python /usr/local/jenkins/slave_scripts/subunit2html.py ./subunit_log.txt testr_results.html
    SUBUNIT_SIZE=$(du -k ./subunit_log.txt | awk '{print $1}')
    gzip -9 ./subunit_log.txt
    gzip -9 ./testr_results.html

    export PYTHON=.tox/$venv/bin/python
    if [[ "$SUBUNIT_SIZE" -gt 50000 ]]; then
        echo
        echo "sub_unit.log was > 50 MB of uncompressed data!!!"
        echo "Something is causing tests for this project to log significant amounts"
        echo "of data. This may be writers to python logging, stdout, or stderr."
        echo "Failing this test as a result"
        echo
        exit 1
    fi

    rancount=$(.tox/$venv/bin/testr last | sed -ne 's/Ran \([0-9]\+\).*tests in.*/\1/p')
    if [ -z "$rancount" ] || [ "$rancount" -eq "0" ] ; then
        echo
        echo "Zero tests were run. At least one test should have been run."
        echo "Failing this test as a result"
        echo
        exit 1
    fi
fi

sudo /usr/local/jenkins/slave_scripts/jenkins-sudo-grep.sh post
sudoresult=$?

if [ $sudoresult -ne "0" ]; then
    echo
    echo "This test has failed because it attempted to execute commands"
    echo "with sudo.  See above for the exact commands used."
    echo
    exit 1
fi

/usr/local/jenkins/slave_scripts/jenkins-oom-grep.sh post
oomresult=$?

if [ $oomresult -ne "0" ]; then
    echo
    echo "This test has failed because it attempted to exceed configured"
    echo "memory limits and was killed prior to completion.  See above"
    echo "for related kernel messages."
    echo
    exit 1
fi

htmlreport=$(find . -name $NOSE_HTML_OUT_FILE)
if [ -f "$htmlreport" ]; then
    passcount=$(grep -c 'tr class=.passClass' $htmlreport)
    if [ $passcount -eq "0" ]; then
        echo
        echo "Zero tests passed, which probably means there was an error"
        echo "parsing one of the python files, or that some other failure"
        echo "during test setup prevented a sane run."
        echo
        exit 1
    fi
else
    echo
    echo "WARNING: Unable to find $NOSE_HTML_OUT_FILE to confirm results!"
    echo
fi

exit $result
