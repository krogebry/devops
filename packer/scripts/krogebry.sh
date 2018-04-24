#!/bin/bash

mkdir -p /home/krogebry/.ssh/keys
mkdir -p /home/krogebry/.chef/keys
mkdir /home/krogebry/dev
mkdir /home/krogebry/.aws

chmod 600 /home/krogebry/.ssh/authorized_keys

mkdir /home/krogebry/.tmp

# gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
curl -sSL https://rvm.io/mpapis.asc | gpg --import -
curl -sSL https://get.rvm.io | bash -s stable

source ~/.bash_profile

rvm install ruby-latest
