#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/asylumexp/Proxmox/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: tremor021
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://github.com/duplicati/duplicati/

APP="Duplicati"
var_tags="${var_tags:-backup}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-10}"
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
    if [[ ! -f /usr/bin/duplicati-server ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi
    
    RELEASE=$(curl -fsSL https://api.github.com/repos/duplicati/duplicati/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4)}')
    if [[ "${RELEASE}" != "$(cat ~/.duplicati)" ]] || [[ ! -f ~/.duplicati ]]; then
        msg_info "Stopping $APP"
        systemctl stop duplicati
        msg_ok "Stopped $APP"
        
        fetch_and_deploy_gh_release "duplicati" "duplicati/duplicati" "binary" "latest" "/opt/duplicati" "linux-x64-gui.deb"

        msg_info "Starting $APP"
        systemctl start duplicati
        msg_ok "Started $APP"

        msg_ok "Update Successful"
    else
        msg_ok "No update required. ${APP} is already at v${RELEASE}"
    fi
    exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8200${CL}"
