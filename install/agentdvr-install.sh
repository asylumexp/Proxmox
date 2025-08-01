#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://www.ispyconnect.com/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  apt-transport-https \
  alsa-utils \
  libxext-dev \
  fontconfig \
  libva-drm2
msg_ok "Installed Dependencies"

msg_info "Installing AgentDVR"
mkdir -p /opt/agentdvr/agent
RELEASE=$(curl -fsSL "https://www.ispyconnect.com/api/Agent/DownloadLocation4?platform=LinuARM64&fromVersion=0" | grep -o 'https://.*\.zip')
cd /opt/agentdvr/agent
curl -fsSL "$RELEASE" -o $(basename "$RELEASE")
$STD unzip Agent_LinuxARM64*.zip
chmod +x ./Agent
msg_ok "Installed AgentDVR"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/AgentDVR.service
[Unit]
Description=AgentDVR

[Service]
WorkingDirectory=/opt/agentdvr/agent
ExecStart=/opt/agentdvr/agent/./Agent
Environment="MALLOC_TRIM_THRESHOLD_=100000"
SyslogIdentifier=AgentDVR
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now AgentDVR
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
rm -rf Agent_LinuxARM64*.zip
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
