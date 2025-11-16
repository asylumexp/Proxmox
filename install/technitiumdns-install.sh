#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/the-guong/Proxmox/raw/main/LICENSE
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
curl -SL -o dotnet.tar.gz https://builds.dotnet.microsoft.com/dotnet/Sdk/9.0.306/dotnet-sdk-9.0.306-linux-arm64.tar.gz
curl -SL -o aspnet.tar.gz https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/9.0.10/aspnetcore-runtime-9.0.10-linux-arm64.tar.gz
$STD mkdir -p /usr/share/dotnet
$STD tar -zxf dotnet.tar.gz -C /usr/share/dotnet
$STD tar -zxf aspnet.tar.gz -C /usr/share/dotnet
ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet
msg_ok "Installed ASP.NET Core Runtime"

RELEASE=$(curl -fsSL https://technitium.com/dns/ | grep -oP 'Version \K[\d.]+')
msg_info "Installing Technitium DNS"
mkdir -p /opt/technitium/dns
curl -fsSL "https://download.technitium.com/dns/DnsServerPortable.tar.gz" -o /opt/DnsServerPortable.tar.gz
$STD tar zxvf /opt/DnsServerPortable.tar.gz -C /opt/technitium/dns/
rm -f /opt/DnsServerPortable.tar.gz
echo "${RELEASE}" >~/.technitium
msg_ok "Installed Technitium DNS"

msg_info "Creating service"
cp /opt/technitium/dns/systemd.service /etc/systemd/system/technitium.service
systemctl enable -q --now technitium 
msg_ok "Service created"

motd_ssh
customize
cleanup_lxc
