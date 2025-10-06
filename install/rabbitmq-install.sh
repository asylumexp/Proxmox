#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://www.rabbitmq.com/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  lsb-release \
  apt-transport-https \
  make \
  software-properties-common
msg_ok "Installed Dependencies"

msg_info "Adding RabbitMQ signing key"
# primary RabbitMQ signing key
curl -1sLf "https://github.com/rabbitmq/signing-keys/releases/download/3.0/rabbitmq-release-signing-key.asc" | sudo gpg --dearmor | sudo tee /usr/share/keyrings/com.github.rabbitmq.signing.gpg > /dev/null

# Launchpad PPA signing key for apt
curl -1sLf "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xf77f1eda57ebb1cc" | sudo gpg --dearmor | sudo tee /usr/share/keyrings/net.launchpad.ppa.rabbitmq.erlang.gpg > /dev/null
msg_ok "Signing keys added"

msg_info "Adding RabbitMQ repository"
cat <<EOF >/etc/apt/sources.list.d/rabbitmq.list
deb [arch=arm64 signed-by=/usr/share/keyrings/net.launchpad.ppa.rabbitmq.erlang.gpg] http://ppa.launchpad.net/rabbitmq/rabbitmq-erlang/ubuntu noble main
deb-src [signed-by=/usr/share/keyrings/net.launchpad.ppa.rabbitmq.erlang.gpg] http://ppa.launchpad.net/rabbitmq/rabbitmq-erlang/ubuntu noble main
EOF
$STD add-apt-repository -y ppa:rabbitmq/rabbitmq-erlang
msg_ok "RabbitMQ repository added"

msg_info "Updating package list"
$STD apt-get update -y
msg_ok "Package list updated"

msg_info "Installing Erlang & RabbitMQ server"
$STD apt-get install -y erlang-base \
  erlang-asn1 erlang-crypto erlang-eldap erlang-ftp erlang-inets \
  erlang-mnesia erlang-os-mon erlang-parsetools erlang-public-key \
  erlang-runtime-tools erlang-snmp erlang-ssl \
  erlang-syntax-tools erlang-tftp erlang-tools erlang-xmerl \
  rabbitmq-server
msg_ok "RabbitMQ server installed"

msg_info "Starting RabbitMQ service"
systemctl enable -q --now rabbitmq-server
msg_ok "RabbitMQ service started"

msg_info "Enabling RabbitMQ management plugin"
$STD rabbitmq-plugins enable rabbitmq_management
$STD rabbitmqctl enable_feature_flag all
msg_ok "RabbitMQ management plugin enabled"

msg_info "Create User"
$STD rabbitmqctl add_user proxmox proxmox
$STD rabbitmqctl set_user_tags proxmox administrator
$STD rabbitmqctl set_permissions -p / proxmox ".*" ".*" ".*"
msg_ok "Created User"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
