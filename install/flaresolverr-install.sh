#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# Co-Author: remz1337
# License: MIT | https://github.com/the-guong/Proxmox/raw/main/LICENSE
# Source: https://github.com/FlareSolverr/FlareSolverr

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y apt-transport-https
$STD apt-get install -y xvfb
$STD apt-get install -y wget
$STD apt-get install -y git
$STD apt-get install -y openssh-server
$STD apt-get install -y chromium-common
$STD apt-mark hold chromium
msg_ok "Installed Dependencies"

msg_info "Installing Chrome"
setup_deb822_repo \
  "google-chrome" \
  "https://dl.google.com/linux/linux_signing_key.pub" \
  "https://dl.google.com/linux/chrome/deb/" \
  "stable"
$STD apt update
$STD apt install -y google-chrome-stable
# remove google-chrome.list added by google-chrome-stable
rm /etc/apt/sources.list.d/google-chrome.list
msg_ok "Installed Chrome"

fetch_and_deploy_gh_release "flaresolverr" "FlareSolverr/FlareSolverr" "prebuild" "v3.4.3" "/opt/flaresolverr" "flaresolverr_linux_arm64.tar.gz"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/flaresolverr.service
[Unit]
Description=FlareSolverr
After=network.target
[Service]
SyslogIdentifier=flaresolverr
Restart=always
RestartSec=5
Type=simple
Environment="LOG_LEVEL=info"
Environment="CAPTCHA_SOLVER=none"
WorkingDirectory=/opt/flaresolverr
ExecStart=python3 /opt/flaresolverr/src/flaresolverr.py
TimeoutStopSec=30
[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now flaresolverr
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
rm /opt/flaresolverr/webdriver.zip
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
