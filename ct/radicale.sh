#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/asylumexp/Proxmox/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: tremor021
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://radicale.org/

APP="Radicale"
var_tags="${var_tags:-calendar}"
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
    if [[ ! -d /opt/radicale ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi

    msg_info "Updating ${APP}"
    python3 -m venv /opt/radicale
    source /opt/radicale/bin/activate
    python3 -m pip install --upgrade https://github.com/Kozea/Radicale/archive/master.tar.gz
    msg_ok "Updated ${APP}"

    msg_info "Starting Service"
    systemctl enable -q --now radicale
    msg_ok "Started Service"

    exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:5232${CL}"