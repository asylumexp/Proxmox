#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
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
$STD apt install -y \
  ffmpeg \
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

fetch_and_deploy_from_url "https://fileflows.com/downloads/zip" "/opt/fileflows"

msg_info "Setup FileFlows"
$STD ln -svf /usr/bin/ffmpeg /usr/local/bin/ffmpeg
$STD ln -svf /usr/bin/ffprobe /usr/local/bin/ffprobe
cd /opt/fileflows/Server
dotnet FileFlows.Server.dll --systemd install --root true
systemctl enable -q --now fileflows
msg_ok "Setup FileFlows"

motd_ssh
customize
cleanup_lxc
