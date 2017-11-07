#!/bin/bash

if [ $(facter virtual) = 'virtualbox' ] ; then
    rm /etc/udev/rules.d/70-persistent-net.rules
    mkdir /etc/udev/rules.d/70-persistent-net.rules
    rm /lib/udev/rules.d/75-persistent-net-generator.rules
    rm -rf /dev/.udev/ /var/lib/dhcp/*
    echo "pre-up sleep 2" >> /etc/network/interfaces
fi

echo "auto enp0s3" >> /etc/network/interfaces
echo "auto enp0s8" >> /etc/network/interfaces
echo "iface enp0s3 inet dhcp" >> /etc/network/interfaces
echo "iface enp0s8 inet dhcp" >> /etc/network/interfaces
