#!/bin/bash -xe
#
# Build a Puppetfile with latest dependencies
#

DIR='puppet-openstack-integration'

# header
echo -e "# Auto-generated Puppetfile for Puppet OpenStack project\n" > $DIR/Puppetfile

# OpenStack Modules
echo "## OpenStack modules" >> $DIR/Puppetfile
for p in $(cat openstack_modules.txt); do
    # hack for puppet-openstack-integration
    # where namespace is openstack_integration
    title=$(echo $p | sed 's/-/_/g')
    # TODO(emilien) we need to add support for stable branches
    cat >> $DIR/Puppetfile <<EOF
mod '$title',
  :git => 'https://git.openstack.org/openstack/puppet-$p',
  :ref => 'master'

EOF
done

# External Modules
echo -e "## External modules" >> $DIR/Puppetfile
for e in $(cat external_modules.txt); do
    namespace=$(echo $e | awk -F'/' '{print $1}' | cut -d "," -f 1)
    module=$(echo $e | awk -F'/' '{print $2}' | cut -d "," -f 1)
    title=$(echo $module | awk -F'/' '{print $1}' | cut -d "-" -f 2)
    pin=$(echo $e | grep "," | cut -d "," -f 2)
    if [ ! -z "$pin" ]; then
        git ls-remote --exit-code https://github.com/$namespace/$module $pin
        if (($? == 2)); then
            echo "Wrong pin: $pin does not exist in $module module."
            exit 1
        else
            tag=$pin
        fi
    else
        git clone https://github.com/$namespace/$module modules/$module
        tag=$(cd modules/$module; git describe --tags $(git rev-list --tags --max-count=1))
        rm -rf modules/$module
    fi
    cat >> $DIR/Puppetfile <<EOF
mod '$title',
  :git => 'https://github.com/$namespace/$module',
  :ref => '$tag'

EOF
done

# for debug
cat $DIR/Puppetfile
