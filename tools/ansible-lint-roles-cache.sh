#!/bin/bash

# This is a bit lame, but if we're running under Zuul then this is set
# to the zuul checkouts of the required roles, so no need to do
# anything here.
if [[ ! ${ANSIBLE_ROLES_PATH} =~ \.cache.* ]]; then
    exit 0
fi

if [ ! -d .cache/ansible-lint ]; then
    mkdir -p .cache/ansible-lint
fi

pushd .cache/ansible-lint

repos=(opendev/base-jobs
        opendev/system-config
        openstack/openstack-zuul-jobs
        zuul/zuul-jobs)

for repo in ${repos[@]}; do
    dir=$(dirname $repo)
    echo "Updating Ansible roles repo ${dir}"
    if [ ! -d $repo ]; then
        echo "Cloning fresh"
        mkdir -p $dir
        pushd $dir
        git clone https://opendev.org/$repo
        popd
    else
        echo "Updating repo"
        pushd $repo
        git fetch -a
        git pull
        popd
    fi
    echo "Done"
done
