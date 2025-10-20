#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://www.proxmox.com/en/proxmox-backup-server

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y git
$STD apt-get install -y dpkg-dev

msg_info "Installing Proxmox Backup Server (Patience)"
export DEBIAN_FRONTEND=noninteractive
git clone https://github.com/wofferl/proxmox-backup-arm64
cd ./proxmox-backup-arm64
$STD ./build.sh install
$STD apt install -y -f ./packages/*
msg_ok "Installed Proxmox Backup Server"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt -y autoremove
$STD apt -y autoclean
$STD apt -y clean
msg_ok "Cleaned"
