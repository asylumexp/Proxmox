#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://www.emqx.com/en

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing EMQX"
$STD bash <(curl -fsSL https://packagecloud.io/install/repositories/emqx/emqx/script.deb.sh)
$STD apt-get install -y emqx
$STD systemctl enable --now emqx
msg_ok "Installed EMQX"

motd_ssh
customize

msg_info "Cleaning up"
apt-get autoremove >/dev/null
apt-get autoclean >/dev/null
msg_ok "Cleaned"
