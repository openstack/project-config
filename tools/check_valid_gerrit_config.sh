#!/bin/bash -e

# It checks that *.config files respect certain gerrit ACL rules

export TMPDIR=`/bin/mktemp -d`
trap "rm -rf $TMPDIR" EXIT

pushd $TMPDIR
CONFIGS_LIST_BASE=$OLDPWD/$1

function check_team_acl {
    local configs_dir="$1"
    local configs_list=$(find $configs_dir -name "*.config")
    local failure=0

    for config in $configs_list; do
        echo "Checking $config file..."

        $OLDPWD/tools/normalize_acl.py $config all > $TMPDIR/normalized
        if ! diff -u $config $TMPDIR/normalized;
        then
            echo "Project $config is not normalized!" >>config_failures
        fi
    done
}

# Add more namespaces here, if necessary
for namespace in openstack openstack-dev openstack-infra stackforge; do
    check_team_acl "${CONFIGS_LIST_BASE}${namespace}"
done

if [ -f config_failures ]; then
    echo -e; cat config_failures
    num_errors=$(wc -l config_failures)
    echo -e "There are $num_errors projects not normalized."
    exit 1
fi

echo "Gerrit ACL configs are valid!"

popd
