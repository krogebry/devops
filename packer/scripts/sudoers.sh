#!/bin/bash

apt-get -y install sudo

# Set up password-less sudo for user vagrant

# no tty
echo "Defaults !requiretty" >> /etc/sudoers

echo "krogebry ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/krogebry
chmod 440 /etc/sudoers.d/krogebry
