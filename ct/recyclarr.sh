#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/asylumexp/Proxmox/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: MrYadro
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://recyclarr.dev/wiki/

APP="Recyclarr"
var_tags="${var_tags:-arr}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-512}"
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
    if [[ ! -f /root/.config/recyclarr/recyclarr.yml ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi

    msg_info "Updating ${APP}"
    curl -fsSL "$(curl -fsSL https://api.github.com/repos/recyclarr/recyclarr/releases/latest | grep download | grep linux-arm64 | cut -d\" -f4)" -o $(basename "$(curl -fsSL https://api.github.com/repos/recyclarr/recyclarr/releases/latest | grep download | grep linux-x64 | cut -d\" -f4)")
    tar -C /usr/local/bin -xJf recyclarr*.tar.xz
    rm -rf recyclarr*.tar.xz
    msg_ok "Updated ${APP}"

    msg_ok "Updated Successfully"
    exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following IP:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}${IP}${CL}"
