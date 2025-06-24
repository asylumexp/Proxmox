#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# Co-Author: Scorpoon
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://github.com/revenz/Fenrus

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y git
msg_ok "Installed Dependencies"

msg_info "Installing ASP.NET Core 7 SDK"
curl -SL -o dotnet.tar.gz https://download.visualstudio.microsoft.com/download/pr/460f951f-0944-442b-8474-555e20394ca8/5fcf6b1845d87d772f919737b3dd5f55/dotnet-sdk-7.0.408-linux-arm64.tar.gz
curl -SL -o aspnet.tar.gz https://download.visualstudio.microsoft.com/download/pr/119db743-de75-4bfd-ac51-f2a2bfd1dd1b/4e96dcef933e3787a34691a86f8972cf/aspnetcore-runtime-7.0.18-linux-arm64.tar.gz
$STD mkdir -p /usr/share/dotnet
$STD tar -zxf dotnet.tar.gz -C /usr/share/dotnet
$STD tar -zxf aspnet.tar.gz -C /usr/share/dotnet
ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet
msg_ok "Installed ASP.NET Core 7 SDK"

msg_info "Installing ${APPLICATION}"
git clone -q https://github.com/revenz/Fenrus.git /opt/${APPLICATION}
cd /opt/${APPLICATION}
$STD dotnet publish -c Release -o "/opt/${APPLICATION}/" Fenrus.csproj
msg_ok "Installed ${APPLICATION}"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/"${APPLICATION}".service
[Unit]
Description=${APPLICATION}

[Service]
WorkingDirectory=/opt/${APPLICATION}
ExecStart=/usr/bin/dotnet Fenrus.dll --urls=http://*:5000
SyslogIdentifier=${APPLICATION}
User=root

[Install]
WantedBy=multi-user.target
EOF
$STD systemctl enable -q --now ${APPLICATION}
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
