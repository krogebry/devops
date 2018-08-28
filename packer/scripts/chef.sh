#!/bin/bash
cd /tmp
curl -L https://www.opscode.com/chef/install.sh | sudo bash
rm -f /tmp/chef*deb

wget "https://packages.chef.io/files/stable/chefdk/3.1.0/debian/9/chefdk_3.1.0-1_amd64.deb"
dpkg -i chefdk_3.1.0-1_amd64.deb