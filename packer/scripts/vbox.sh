#!/bin/bash

## Virtual box
echo 'deb http://download.virtualbox.org/virtualbox/debian stretch contrib' >> /etc/apt/sources.list
wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo apt-key add -
apt-get update -y 
apt-get install virtualbox-5.2 -y
