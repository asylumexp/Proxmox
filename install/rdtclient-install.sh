#!/usr/bin/env bash

# Copyright (c) 2021-2026 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://github.com/rogerfar/rdt-client

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y unzip
msg_ok "Installed Dependencies"

msg_info "Installing ASP.NET Core Runtime"
$STD apt-get install -y libc6
$STD apt-get install -y libgcc1
$STD apt-get install -y libgssapi-krb5-2
$STD apt-get install -y libicu72
$STD apt-get install -y liblttng-ust1
$STD apt-get install -y libssl3
$STD apt-get install -y libstdc++6
$STD apt-get install -y zlib1g

curl -SL -o dotnet.tar.gz https://download.visualstudio.microsoft.com/download/pr/6f79d99b-dc38-4c44-a549-32329419bb9f/a411ec38fb374e3a4676647b236ba021/dotnet-sdk-9.0.100-linux-arm64.tar.gz
mkdir -p /usr/share/dotnet
$STD tar -zxf dotnet.tar.gz -C /usr/share/dotnet
$STD ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet
msg_ok "Installed ASP.NET Core Runtime"

fetch_and_deploy_gh_release "rdt-client" "rogerfar/rdt-client" "prebuild" "latest" "/opt/rdtc" "RealDebridClient.zip"

msg_info "Setting up rdtclient"
cd /opt/rdtc
mkdir -p data/{db,downloads}
sed -i 's#/data/db/#/opt/rdtc&#g' /opt/rdtc/appsettings.json
msg_ok "Configured rdtclient"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/rdtc.service
[Unit]
Description=RdtClient Service

[Service]
WorkingDirectory=/opt/rdtc
ExecStart=/usr/bin/dotnet RdtClient.Web.dll
SyslogIdentifier=RdtClient
User=root

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now rdtc
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
