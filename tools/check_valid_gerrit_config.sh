#!/bin/bash -e

# It checks that *.config files respect certain gerrit ACL rules

TMPDIR=$(mktemp -d)
export TMPDIR
trap "rm -rf $TMPDIR" EXIT

pushd $TMPDIR
CONFIGS_LIST_BASE=$OLDPWD/gerrit/acls

declare -i NUM_TESTS=0

function check_team_acl {
    local configs_dir="$1"
    local namespace
    local configs_list

    namespace="$(basename $configs_dir)"
    echo "Checking $namespace"
    configs_list=$(find $configs_dir -name "*.config")
    for config in $configs_list; do
        let "NUM_TESTS+=1"
        $OLDPWD/tools/normalize_acl.py $namespace $config all \
                                       > $TMPDIR/normalized
        if ! diff -u $config $TMPDIR/normalized >>config_failures;
        then
            echo "Project $config is not normalized!" >>config_failures
        fi
    done
}

# Add more namespaces here, if necessary
for namespace in $CONFIGS_LIST_BASE/*; do
    if [ -d $namespace ] ; then
        check_team_acl "${namespace}"
    fi
done

num_errors=$(cat config_failures | grep "is not normalized" | wc -l)
if [ $num_errors -ne 0 ]; then
    echo -e; cat config_failures
    echo -e "There are $num_errors projects not normalized."
    echo
    echo -e "******************************************************"
    $OLDPWD/tools/normalize_acl.py -help
    echo -e "******************************************************"
    exit 1
fi

echo "Gerrit ACL configs are valid!"
echo "Checked $NUM_TESTS ACL files"

popd
