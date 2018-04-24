#!/bin/bash

apt-get -y install sudo

# no tty
echo "Defaults !requiretty" >> /etc/sudoers

adduser krogebry docker

echo "krogebry ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/krogebry
chmod 440 /etc/sudoers.d/krogebry
