#!/bin/bash -xe

# Working variables
WHEELHOUSE_DIR=$1
WORKING_DIR=$(pwd)/src/git.openstack.org/openstack/requirements
PYTHON_VERSION=$2
LOGS=$(pwd)/logs

FAIL_LOG=${LOGS}/failed.txt

# preclean logs
mkdir -p ${LOGS}
rm -rf ${LOGS}/*

# Extract and iterate over all the branch names.
BRANCHES=`git --git-dir=$WORKING_DIR/.git branch -a | grep '^  stable'`
for BRANCH in master $BRANCHES; do
    git --git-dir=$WORKING_DIR/.git show $BRANCH:upper-constraints.txt \
        2>/dev/null > /tmp/upper-constraints.txt  || true

    # setup the building virtualenv.  We want to freshen this for each
    # branch.
    rm -rf build_env
    virtualenv -p $PYTHON_VERSION build_env

    # SHORT_BRANCH is just "master","newton","kilo" etc. because this
    # keeps the output log hierarchy much simpler.
    SHORT_BRANCH=${BRANCH##origin/}
    SHORT_BRANCH=${SHORT_BRANCH##stable/}

    # Failed parallel jobs don't fail the whole job, we just report
    # the issues for investigation.
    set +e

    # This runs all the jobs under "parallel".  The stdout, stderr and
    # exit status for each pip invocation will be captured into files
    # kept in ${LOGS}/build/${SHORT_BRANCH}/1/[package].  The --joblog
    # file keeps an overview of all run jobs, which we can probe to
    # find failed jobs.
    cat /tmp/upper-constraints.txt | \
        parallel --files --progress --joblog ${LOGS}/$SHORT_BRANCH-job.log \
                --results ${LOGS}/build/$SHORT_BRANCH \
                build_env/bin/pip --verbose wheel -w $WHEELHOUSE_DIR {}
    set -e

    # Column $7 is the exit status of the job, $14 is the last
    # argument to pip, which is our package.
    FAILED=$(awk -e '$7!=0 {print $14}' ${LOGS}/$SHORT_BRANCH-job.log)
    if [ -n "${FAILED}" ]; then
        echo "*** FAILED BUILDS FOR BRANCH ${BRANCH}" >> ${FAIL_LOG}
        echo "${FAILED}" >> ${FAIL_LOG}
        echo -e "***\n\n" >> ${FAIL_LOG}
    fi
done

if [ -f ${FAIL_LOG} ]; then
    cat ${FAIL_LOG}
fi

# XXX This does make a lot of log files; about 80mb after compression.
# In theory we could correlate just the failed logs and keep those
# from the failure logs above.  This is currently (2017-01) left as an
# exercise for when the job is stable :) bz2 gave about 20%
# improvement over gzip in testing.
pushd ${LOGS}
tar zcvf build-logs.tar.gz ./build
rm -rf ./build
popd
