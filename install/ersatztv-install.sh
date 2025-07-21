#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck
# Author: MickLesk (Canbiz)
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://ersatztv.org/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Setting Up Hardware Acceleration"
$STD apt-get -y install {va-driver-all,ocl-icd-libopencl1,intel-opencl-icd,vainfo,intel-gpu-tools}
if [[ "$CTTYPE" == "0" ]]; then
  chgrp video /dev/dri
  chmod 755 /dev/dri
  chmod 660 /dev/dri/*
  $STD adduser $(id -u -n) video
  $STD adduser $(id -u -n) render
fi
msg_ok "Set Up Hardware Acceleration"

fetch_and_deploy_gh_release "ersatztv" "ErsatzTV/ErsatzTV" "prebuild" "latest" "/opt/ErsatzTV" "*linux-arm64.tar.gz"
fetch_and_deploy_gh_release "ersatztv-ffmpeg" "ErsatzTV/ErsatzTV-ffmpeg" "prebuild" "latest" "/opt/ErsatzTV-ffmpeg" "*-linuxarm64-gpl-7.1.tar.xz"

msg_info "Set ErsatzTV-ffmpeg links"
chmod +x /opt/ErsatzTV-ffmpeg/bin/*
ln -sf /opt/ErsatzTV-ffmpeg/bin/ffmpeg /usr/local/bin/ffmpeg
ln -sf /opt/ErsatzTV-ffmpeg/bin/ffplay /usr/local/bin/ffplay
ln -sf /opt/ErsatzTV-ffmpeg/bin/ffprobe /usr/local/bin/ffprobe
msg_ok "ffmpeg links set"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/ersatzTV.service
[Unit]
Description=ErsatzTV Service
After=multi-user.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/ErsatzTV
ExecStart=/opt/ErsatzTV/ErsatzTV
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now ersatzTV
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
