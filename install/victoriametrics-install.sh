#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: Slaviša Arežina (tremor021)
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://github.com/VictoriaMetrics/VictoriaMetrics

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

fetch_and_deploy_gh_release "victoriametrics" "VictoriaMetrics/VictoriaMetrics" "prebuild" "latest" "/opt/victoriametrics" "victoria-metrics-linux-arm64-v+([0-9.]).tar.gz"
fetch_and_deploy_gh_release "vmutils" "VictoriaMetrics/VictoriaMetrics" "prebuild" "latest" "/opt/victoriametrics" "vmutils-linux-arm64-v+([0-9.]).tar.gz"
fetch_and_deploy_gh_release "victorialogs" "VictoriaMetrics/VictoriaLogs" "prebuild" "latest" "/opt/victoriametrics" "victoria-logs-linux-arm64*.tar.gz"
fetch_and_deploy_gh_release "vlutils" "VictoriaMetrics/VictoriaLogs" "prebuild" "latest" "/opt/victoriametrics" "vlutils-linux-arm64*.tar.gz"

msg_info "Setup VictoriaMetrics"
mkdir -p /opt/victoriametrics/data
chmod +x /opt/victoriametrics/*
msg_ok "Setup VictoriaMetrics"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/victoriametrics.service
[Unit]
Description=VictoriaMetrics Service

[Service]
Type=simple
Restart=always
User=root
WorkingDirectory=/opt/victoriametrics
ExecStart=/opt/victoriametrics/victoria-metrics-prod --storageDataPath="/opt/victoriametrics/data"

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/etc/systemd/system/victoriametrics-logs.service
[Unit]
Description=VictoriaMetrics Service

[Service]
Type=simple
Restart=always
User=root
WorkingDirectory=/opt/victoriametrics
ExecStart=/opt/victoriametrics/victoria-logs-prod

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now victoriametrics
systemctl enable -q --now victoriametrics-logs
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
rm -rf $temp_dir
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
