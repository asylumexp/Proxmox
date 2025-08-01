#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://overseerr.dev/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  git \
  ca-certificates
msg_ok "Installed Dependencies"

NODE_VERSION="22" NODE_MODULE="yarn@latest" setup_nodejs

msg_info "Installing Overseerr (Patience)"
git clone -q https://github.com/sct/overseerr.git /opt/overseerr
cd /opt/overseerr
$STD yarn install
$STD yarn build
msg_ok "Installed Overseerr"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/overseerr.service
[Unit]
Description=Overseerr Service
After=network.target

[Service]
Type=exec
WorkingDirectory=/opt/overseerr
ExecStart=/usr/bin/yarn start

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now overseerr
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
