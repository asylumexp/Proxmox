#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck
# Author: chrisbenincasa
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://tunarr.com/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Setting Up Hardware Acceleration"
if [[ "$CTTYPE" == "0" ]]; then
  $STD adduser "$(id -un)" video
  $STD adduser "$(id -un)" render
fi
msg_ok "Base Hardware Acceleration Set Up"


msg_info "Installing Hardware Acceleration"
$STD apt -y install \
  ocl-icd-libopencl1 \   # OpenCL loader
  mesa-opencl-icd \      # Mesa (Rusticl) OpenCL for GPUs Mesa supports
  clinfo \               # OpenCL capability probe
  libva2 libva-drm2 \    # VA-API userspace
  vainfofi
msg_ok "Installed and Set Up Hardware Acceleration"

fetch_and_deploy_gh_release "tunarr" "chrisbenincasa/tunarr" "singlefile" "latest" "/opt/tunarr" "*linux-arm64"
fetch_and_deploy_gh_release "ersatztv-ffmpeg" "ErsatzTV/ErsatzTV-ffmpeg" "prebuild" "latest" "/opt/ErsatzTV-ffmpeg" "*-linuxarm64-gpl-7.1.tar.xz"

msg_info "Set ErsatzTV-ffmpeg links"
chmod +x /opt/ErsatzTV-ffmpeg/bin/*
ln -sf /opt/ErsatzTV-ffmpeg/bin/ffmpeg /usr/bin/ffmpeg
ln -sf /opt/ErsatzTV-ffmpeg/bin/ffplay /usr/bin/ffplay
ln -sf /opt/ErsatzTV-ffmpeg/bin/ffprobe /usr/bin/ffprobe
msg_ok "ffmpeg links set"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/tunarr.service
[Unit]
Description=Tunarr Service
After=multi-user.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/tunarr
ExecStart=/opt/tunarr/tunarr
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now tunarr
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt -y autoremove
$STD apt -y autoclean
$STD apt -y clean
msg_ok "Cleaned"
