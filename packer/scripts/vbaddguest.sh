#!/usr/bin/env bash
set -xe
mkdir /tmp/vbox
cd /tmp
wget "http://download.virtualbox.org/virtualbox/5.2.0_RC1/VBoxGuestAdditions_5.2.0_RC1.iso"
mount -o loop VBoxGuestAdditions_5.2.0_RC1.iso /tmp/vbox
apt-get install build-essential module-assistant linux-headers-amd64 -y
mkdir /usr/src/linux-headers-$(uname -r)/include/linux
ln -s /usr/src/linux-headers-$(uname -r)/include/generated/autoconf.h /usr/src/linux-headers-$(uname -r)/include/linux/
cd /tmp/vbox ; yes | sh /tmp/vbox/VBoxLinuxAdditions.run
modprobe vboxsf
