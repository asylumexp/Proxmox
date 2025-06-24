#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://www.audiobookshelf.org/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y gnupg
$STD apt-get install -y ffmpeg
$STD apt-get install -y git
msg_ok "Installed Dependencies"

msg_info "Installing Node.js"
$STD apt-get update
$STD apt-get install -y nodejs
$STD apt-get install -y npm
msg_ok "Installed Node.js"

msg_info "Installing audiobookshelf (Patience)"
$STD git clone https://github.com/advplyr/audiobookshelf /opt/audiobookshelf
cd /opt/audiobookshelf
mv ./.devcontainer/dev.js ./dev.js
sed -i 's/Port: 3333/Port: 13378/' ./dev.js
sed -i "s|ConfigPath: Path.resolve('config'),|ConfigPath: '/usr/share/audiobookshelf/config',|" ./dev.js
sed -i "s|MetadataPath: Path.resolve('metadata'),|MetadataPath: '/usr/share/audiobookshelf/metadata',|" ./dev.js
$STD npm ci 
cd client
$STD npm ci
$STD npm run generate
mkdir -p /usr/share/audiobookshelf/config
mkdir -p /usr/share/audiobookshelf/metadata
msg_ok "Installed audiobookshelf"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/audiobookshelf_client.service
[Unit]
Description=Audiobookshelf Client Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/audiobookshelf/client
ExecStart=/usr/bin/npm run dev
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
cat <<EOF >/etc/systemd/system/audiobookshelf_server.service
[Unit]
Description=Audiobookshelf Server Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/audiobookshelf/
ExecStart=/usr/bin/npm run dev
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now audiobookshelf_server.service
systemctl enable -q --now audiobookshelf_client.service
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
