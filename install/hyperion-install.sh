#!/usr/bin/env bash

# Copyright (c) 2021-2026 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://hyperion-project.org/forum/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os
setup_hwaccel


msg_info "Installing Dependencies"
$STD apt-get install -y lsb-release
$STD apt-get install -y apt-transport-https
$STD apt-get install -y libpython3.11
msg_ok "Installed Dependencies"

msg_info "Setting up Hyperion repository"
setup_deb822_repo \
  "hyperion" \
  "https://releases.hyperion-project.org/hyperion.pub.key" \
  "https://apt.releases.hyperion-project.org" \
  "$(get_os_info codename)"
msg_ok "Set up Hyperion repository"


msg_info "Installing Hyperion"
$STD apt install -y hyperion
systemctl enable -q --now hyperion@root
msg_ok "Installed Hyperion"

motd_ssh
customize
cleanup_lxc
