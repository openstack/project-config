#!/bin/bash

# Create the nodepool-dib.yaml dashboard with nodepool dib build
# status.

output_file=nodepool-dib.yaml

function create {
    local title="$1"
    local key="$2"

    sed -e "s/%TITLE%/${title}/; " \
        -e "s/%KEY%/${key}/" \
        nodepool-dib.image.template >> ${output_file}
}

cp nodepool-dib.base.template nodepool-dib.yaml
create "Ubuntu Bionic" "ubuntu-bionic"
create "Ubuntu Xenial" "ubuntu-xenial"
create "Ubuntu Trusty" "ubuntu-trusty"
create "Centos 7" "centos-7"
create "Fedora 29" "fedora-29"
create "Debian Buster" "debian-buster"
create "Debian Stretch" "debian-stretch"
create "Gentoo" "gentoo-17-0-systemd"
create "openSUSE 15.0" "opensuse-150"
create "openSUSE 15" "opensuse-15"
create "openSUSE 42.3" "opensuse-423"
create "Ubuntu Bionic arm64" "ubuntu-bionic-arm64"
create "Ubuntu Xenial arm64" "ubuntu-xenial-arm64"

