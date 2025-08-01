#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: havardthom
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://neo4j.com/product/neo4j-graph-database/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  lsb-release
msg_ok "Installed Dependencies"

msg_info "Setting up Adoptium Repository"
mkdir -p /etc/apt/keyrings
curl -fsSL "https://packages.adoptium.net/artifactory/api/gpg/key/public" | gpg --dearmor >/etc/apt/trusted.gpg.d/adoptium.gpg
echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" >/etc/apt/sources.list.d/adoptium.list
msg_ok "Set up Adoptium Repository"

msg_info "Installing Neo4j (patience)"
curl -fsSL "https://debian.neo4j.com/neotechnology.gpg.key" | gpg --dearmor -o /etc/apt/keyrings/neotechnology.gpg
echo 'deb [signed-by=/etc/apt/keyrings/neotechnology.gpg] https://debian.neo4j.com stable latest' >/etc/apt/sources.list.d/neo4j.list
$STD apt-get update
$STD apt-get install -y temurin-21-jre
$STD apt-get install -y neo4j
sed -i '/server.default_listen_address/s/^#//' /etc/neo4j/neo4j.conf
systemctl enable -q --now neo4j
msg_ok "Installed Neo4j"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
