#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://www.mongodb.com/de-de

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

cpu_info=$(lscpu)

if ! echo "$cpu_info" | grep -q 'asimdrdm\|asimdhf\|dotprod\|fp16'; then
    msg_error "This machine does not support ARMv8.2-A."
    exit
fi

read -p "${TAB3}Do you want to install MongoDB 8.0 instead of 7.0? [y/N]: " install_mongodb_8
if [[ "$install_mongodb_8" =~ ^[Yy]$ ]]; then
  MONGO_VERSION="8.0" setup_mongodb
else
  MONGO_VERSION="7.0" setup_mongodb
fi
sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf

motd_ssh
customize
cleanup_lxc
