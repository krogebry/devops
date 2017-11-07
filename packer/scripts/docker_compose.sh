#!/bin/bash

## Docker compose
curl -L https://github.com/docker/compose/releases/download/1.16.1/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
chmod 755 /usr/local/bin/docker-compose
# echo 'alias dc="/usr/local/bin/docker-compose' >> /home/krogebry/.bashrc
