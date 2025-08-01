#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://www.iventoy.com/en/index.html

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

RELEASE=$(curl -fsSL https://api.github.com/repos/ventoy/pxe/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
msg_info "Installing iVentoy v${RELEASE}"
mkdir -p /opt/iventoy/{data,iso}
curl -fsSL "https://github.com/ventoy/PXE/releases/download/v${RELEASE}/iventoy-${RELEASE}-linux-free.tar.gz" -o "iventoy-${RELEASE}-linux-free.tar.gz"
tar -C /tmp -xzf iventoy*.tar.gz
mv /tmp/iventoy*/* /opt/iventoy/
rm -rf iventoy*.tar.gz
msg_ok "Installed iVentoy"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/iventoy.service
[Unit]
Description=iVentoy PXE Booter
Documentation=https://www.iventoy.com
Wants=network-online.target
[Service]
Type=forking
Environment=IVENTOY_API_ALL=1
Environment=IVENTOY_AUTO_RUN=1
Environment=LIBRARY_PATH=/opt/iventoy/lib/lin64
Environment=LD_LIBRARY_PATH=/opt/iventoy/lib/lin64
ExecStart=sh ./iventoy.sh -R start
WorkingDirectory=/opt/iventoy
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now iventoy
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
