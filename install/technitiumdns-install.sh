#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://technitium.com/dns/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y curl
$STD apt-get install -y sudo
$STD apt-get install -y mc
$STD apt-get install -y wget
$STD apt-get install -y openssh-server
msg_ok "Installed Dependencies"

msg_info "Installing ASP.NET Core Runtime"
curl -SL -o dotnet.tar.gz https://download.visualstudio.microsoft.com/download/pr/1e449990-2934-47ee-97fb-b78f0e587c98/1c92c33593932f7a86efa5aff18960ed/dotnet-sdk-8.0.204-linux-arm64.tar.gz
curl -SL -o aspnet.tar.gz https://download.visualstudio.microsoft.com/download/pr/80ec12e5-b26f-466c-a20c-f96772ea709d/606e7203912400b44cb35d6fcecf60bf/aspnetcore-runtime-8.0.4-linux-arm64.tar.gz
$STD mkdir -p /usr/share/dotnet
$STD tar -zxf dotnet.tar.gz -C /usr/share/dotnet
$STD tar -zxf aspnet.tar.gz -C /usr/share/dotnet
ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet
msg_ok "Installed ASP.NET Core Runtime"

msg_info "Installing Technitium DNS"
$STD bash <(curl -fsSL https://download.technitium.com/dns/install.sh)
msg_ok "Installed Technitium DNS"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
