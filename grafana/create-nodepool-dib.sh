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
create "Ubuntu Focal" "ubuntu-focal"
create "Ubuntu Bionic" "ubuntu-bionic"
create "Ubuntu Xenial" "ubuntu-xenial"
create "Centos 7" "centos-7"
create "Centos 8 Stream" "centos-8-stream"
create "Centos 9 Stream" "centos-9-stream"
create "Fedora 35" "fedora-35"
create "Debian Bullseye" "debian-bullseye"
create "Debian Buster" "debian-buster"
create "Gentoo" "gentoo-17-0-systemd"
create "openSUSE 15.1" "opensuse-15"
create "Centos 8-stream arm64" "centos-8-stream-arm64"
create "Debian Bullseye arm64" "debian-bullseye-arm64"
create "Debian Buster arm64" "debian-buster-arm64"
create "Ubuntu Focal arm64" "ubuntu-focal-arm64"
create "Ubuntu Bionic arm64" "ubuntu-bionic-arm64"

