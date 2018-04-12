#!/bin/bash

apt-get update
apt-get install -y \
    apt-transport-https \
	awscli \
	rdate \
	jq \
    net-tools \
	mlocate \
    curl \
    dirmngr \
    gnupg2 \
    software-properties-common gawk \
    g++ \
    libyaml-dev \
    libsqlite3-dev \
    sqlite3 \
    autoconf \
    libgmp-dev \
    vim \
    sshpass \
    pssh \
    awscli \
    python3-pip \
    dirmngr \
    libyajl-dev \
    ca-certificates
    libgdbm-dev \
    libncurses5-dev \
    automake \
    libtool \
    bison \
    sudo \
    pkg-config \
    libffi-dev \
    libgmp-dev \
    libreadline-dev \
    libssl-dev

updatedb &

echo "set -o vi" >> /root/.bashrc

pip3 install awscli --upgrade

usermod -aG sudo krogebry
