#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/asylumexp/Proxmox/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: Slaviša Arežina (tremor021)
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://github.com/Casvt/Kapowarr

APP="Kapowarr"
var_tags="${var_tags:-Arr}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-256}"
var_disk="${var_disk:-2}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -f /etc/systemd/system/kapowarr.service ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  RELEASE=$(curl -s https://api.github.com/repos/Casvt/Kapowarr/releases/latest | grep "tag_name" | awk '{print substr($2, 2, length($2)-3) }')
  if [[ "${RELEASE}" != "$(cat $HOME/.kapowarr)" ]] || [[ ! -f $HOME/.kapowarr ]]; then
    setup_uv 
    
    msg_info "Stopping $APP"
    systemctl stop kapowarr
    msg_ok "Stopped $APP"

    msg_info "Creating Backup"
    mv /opt/kapowarr/db /opt/
    msg_ok "Backup Created"

    fetch_and_deploy_gh_release "kapowarr" "Casvt/Kapowarr"
    msg_info "Updating $APP to ${RELEASE}"
    mv /opt/db /opt/kapowarr
    msg_ok "Updated $APP to ${RELEASE}"

    msg_info "Starting $APP"
    systemctl start kapowarr
    msg_ok "Started $APP"

    msg_ok "Update Successful"
  else
    msg_ok "No update required. ${APP} is already at ${RELEASE}"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:5656${CL}"
