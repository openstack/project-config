#!/bin/bash -xe
# Copyright (C) 2014 Hewlett-Packard Development Company, L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
#
# See the License for the specific language governing permissions and
# limitations under the License.

# Set the grub timeout to 0.
if [ -f /etc/default/grub ] ; then
    sudo sed -i -e 's/^GRUB_TIMEOUT=[0-9]\+/GRUB_TIMEOUT=0/' \
        /etc/default/grub
    if which update-grub &> /dev/null ; then
        sudo update-grub
    else
        # If update-grub isn't available, use grub2-mkconfig directly
        sudo /usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg
    fi
elif [ -f /boot/grub/grub.conf ] ; then
    sudo sed -i -e 's/^timeout=[0-9]\+/timeout=0/' \
        /boot/grub/grub.conf
fi
