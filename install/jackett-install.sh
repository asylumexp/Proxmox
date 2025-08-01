#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://github.com/Jackett/Jackett

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Jackett"
RELEASE=$(curl -fsSL https://github.com/Jackett/Jackett/releases/latest | grep "title>Release" | cut -d " " -f 4)
cd /opt
curl -fsSL "https://github.com/Jackett/Jackett/releases/download/$RELEASE/Jackett.Binaries.LinuxARM64.tar.gz" -o "Jackett.Binaries.LinuxARM64.tar.gz"
tar -xzf Jackett.Binaries.LinuxARM64.tar.gz -C /opt
rm -rf Jackett.Binaries.LinuxARM64.tar.gz
echo "${RELEASE}" >/opt/${APPLICATION}_version.txt
msg_ok "Installed Jackett"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/jackett.service
[Unit]
Description=Jackett Daemon
After=network.target
[Service]
SyslogIdentifier=jackett
Restart=always
RestartSec=5
Type=simple
WorkingDirectory=/opt/Jackett
ExecStart=/bin/sh /opt/Jackett/jackett_launcher.sh
TimeoutStopSec=30
Environment="DisableRootWarning=true"
[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now jackett
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
