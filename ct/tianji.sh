#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/asylumexp/Proxmox/main/misc/build.func)
# Copyright (c) 2021-2025 tteck
# Author: MickLesk (Canbiz)
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://tianji.msgbyte.com/

APP="Tianji"
var_tags="${var_tags:-monitoring}"
var_cpu="${var_cpu:-4}"
var_ram="${var_ram:-4096}"
var_disk="${var_disk:-12}"
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
  if [[ ! -d /opt/tianji ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  if ! command -v jq &>/dev/null; then
    $STD apt-get install -y jq
  fi
  if ! command -v node >/dev/null || [[ "$(/usr/bin/env node -v | grep -oP '^v\K[0-9]+')" != "22" ]]; then
    msg_info "Installing Node.js 22"
    $STD apt-get purge -y nodejs
    rm -f /etc/apt/sources.list.d/nodesource.list
    rm -f /etc/apt/keyrings/nodesource.gpg
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" >/etc/apt/sources.list.d/nodesource.list
    $STD apt-get update
    $STD apt-get install -y nodejs
    $STD npm install -g pnpm@9.7.1
    msg_ok "Node.js 22 installed"
  fi
  RELEASE=$(curl -fsSL https://api.github.com/repos/msgbyte/tianji/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
  if [[ ! -f /opt/${APP}_version.txt ]] || [[ "${RELEASE}" != "$(cat /opt/${APP}_version.txt)" ]]; then
    msg_info "Stopping ${APP} Service"
    systemctl stop tianji
    msg_ok "Stopped ${APP} Service"

    msg_info "Updating ${APP} to v${RELEASE}"
    cd /opt
    cp /opt/tianji/src/server/.env /opt/.env
    mv /opt/tianji /opt/tianji_bak
    curl -fsSL "https://github.com/msgbyte/tianji/archive/refs/tags/v${RELEASE}.zip" -o $(basename "https://github.com/msgbyte/tianji/archive/refs/tags/v${RELEASE}.zip")
    $STD unzip v${RELEASE}.zip
    mv tianji-${RELEASE} /opt/tianji
    cd tianji
    export NODE_OPTIONS="--max_old_space_size=4096"
    $STD pnpm install --filter @tianji/client... --config.dedupe-peer-dependents=false --frozen-lockfile
    $STD pnpm build:static
    $STD pnpm install --filter @tianji/server... --config.dedupe-peer-dependents=false
    mkdir -p ./src/server/public
    cp -r ./geo ./src/server/public
    $STD pnpm build:server
    mv /opt/.env /opt/tianji/src/server/.env
    cd src/server
    $STD pnpm db:migrate:apply
    echo "${RELEASE}" >/opt/${APP}_version.txt
    msg_ok "Updated ${APP} to v${RELEASE}"

    msg_info "Starting ${APP}"
    systemctl start tianji
    msg_ok "Started ${APP}"

    msg_info "Cleaning up"
    rm -R /opt/v${RELEASE}.zip
    rm -rf /opt/tianji_bak
    rm -rf /opt/tianji/src/client
    rm -rf /opt/tianji/website
    rm -rf /opt/tianji/reporter
    msg_ok "Cleaned"
    msg_ok "Updated Successfully"
  else
    msg_ok "No update required.  ${APP} is already at v${RELEASE}."
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:12345${CL}"
