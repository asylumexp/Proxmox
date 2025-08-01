#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://gotify.net/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Gotify"
RELEASE=$(curl -fsSL https://api.github.com/repos/gotify/server/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
mkdir -p /opt/gotify
cd /opt/gotify
curl -fsSL "https://github.com/gotify/server/releases/download/v${RELEASE}/gotify-linux-arm64.zip" -o "gotify-linux-arm64.zip"
$STD unzip gotify-linux-arm64.zip
rm -rf gotify-linux-arm64.zip
chmod +x gotify-linux-arm64
echo "${RELEASE}" >/opt/${APPLICATION}_version.txt
msg_ok "Installed Gotify"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/gotify.service
[Unit]
Description=Gotify
Requires=network.target
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/gotify
ExecStart=/opt/gotify/./gotify-linux-arm64
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now gotify
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
