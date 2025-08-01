#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/asylumexp/Proxmox/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: Slaviša Arežina (tremor021)
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://minarca.org/en_CA

APP="Minarca"
var_tags="${var_tags:-backup}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-4096}"
var_disk="${var_disk:-10}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"
var_fuse="${var_fuse:-yes}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/minarca-server ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  msg_info "Stopping ${APP}"
  systemctl stop minarca-server
  msg_ok "${APP} Stopped"

  msg_info "Updating ${APP} LXC"
  $STD apt-get update
  $STD apt-get upgrade -y
  msg_ok "Updated ${APP} LXC"

  msg_info "Starting ${APP}"
  systemctl start minarca-server
  msg_ok "Restarted ${APP}"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8080${CL}"
