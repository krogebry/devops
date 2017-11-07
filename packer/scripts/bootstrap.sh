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
  gnupg2 \
  software-properties-common gawk \
  g++ \
  libyaml-dev \
  libsqlite3-dev \
  sqlite3 \
  autoconf \
  libgmp-dev \
  libgdbm-dev \
  libncurses5-dev \
  automake \
  libtool \
  bison \
  pkg-config \
  libffi-dev \
  libgmp-dev \
  libreadline-dev \
  libssl-dev

updatedb &

echo "Defaults !requiretty" >> /etc/sudoers
