#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: kkroboth
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://fileflows.com/

# Import Functions und Setup
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  ffmpeg \
  jq \
  imagemagick
msg_ok "Installed Dependencies"

setup_hwaccel

msg_info "Installing ASP.NET Core Runtime"
curl -SL -o aspnet.tar.gz https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/8.0.16/aspnetcore-runtime-8.0.16-linux-arm64.tar.gz
$STD mkdir -p /usr/share/dotnet
$STD tar -zxf aspnet.tar.gz -C /usr/share/dotnet
ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet
$STD rm -f aspnet.tar.gz
msg_ok "Installed ASP.NET Core Runtime"

msg_info "Setup ${APPLICATION}"
$STD ln -svf /usr/bin/ffmpeg /usr/local/bin/ffmpeg
$STD ln -svf /usr/bin/ffprobe /usr/local/bin/ffprobe
temp_file=$(mktemp)
curl -fsSL https://fileflows.com/downloads/zip -o "$temp_file"
$STD unzip -d /opt/fileflows "$temp_file"
(cd /opt/fileflows/Server && dotnet FileFlows.Server.dll --systemd install --root true)
systemctl enable -q --now fileflows
rm -f "$temp_file"
msg_ok "Setup ${APPLICATION}"

motd_ssh
customize
cleanup_lxc
