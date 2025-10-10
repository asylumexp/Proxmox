#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: Slaviša Arežina (tremor021)
# License: MIT | https://github.com/asylumexp/Proxmox/raw/main/LICENSE
# Source: https://github.com/wger-project/wger

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  git \
  apache2 \
  libapache2-mod-wsgi-py3 \
  jq
msg_ok "Installed Dependencies"

setup_uv

NODE_VERSION="22" NODE_MODULE="yarn,sass" setup_nodejs

WGER_USER="wger"
WGER_HOME="/home/${WGER_USER}"
WGER_SRC="${WGER_HOME}/src"
WGER_DB_DIR="${WGER_HOME}/db"
WGER_STATIC="${WGER_HOME}/static"
WGER_MEDIA="${WGER_HOME}/media"
WGER_VENV="${WGER_HOME}/.venv"

msg_info "Setting up wger user and directories"
$STD adduser "$WGER_USER" --disabled-password --gecos ""
mkdir -p "$WGER_DB_DIR" "$WGER_STATIC" "$WGER_MEDIA"
touch "${WGER_DB_DIR}/database.sqlite"
chown -R ${WGER_USER}:www-data "$WGER_HOME"
chmod g+w "$WGER_DB_DIR" "${WGER_DB_DIR}/database.sqlite"
chmod o+w "$WGER_MEDIA"
msg_ok "Prepared user and directories"

msg_info "Fetching latest wger release"
temp_dir=$(mktemp -d)
cd "$temp_dir" || exit 1
RELEASE=$(curl -fsSL https://api.github.com/repos/wger-project/wger/releases/latest \
  | grep "tag_name" | awk '{print substr($2, 2, length($2)-3)}')
curl -fsSL "https://github.com/wger-project/wger/archive/refs/tags/${RELEASE}.tar.gz" -o "${RELEASE}.tar.gz"
tar xzf "${RELEASE}.tar.gz"
mv "wger-${RELEASE}" "$WGER_SRC"
chown -R ${WGER_USER}:${WGER_USER} "$WGER_SRC"
cd "$WGER_SRC" || exit 1
msg_ok "Downloaded wger ${RELEASE}"

msg_info "Creating uv virtual environment"
$STD uv venv "$WGER_VENV"
chown -R ${WGER_USER}:${WGER_USER} "$WGER_VENV"
msg_ok "Created uv venv at ${WGER_VENV}"

msg_info "Installing Python dependencies with uv"
$STD uv pip install --python "${WGER_VENV}/bin/python" -r requirements_prod.txt
$STD uv pip install --python "${WGER_VENV}/bin/python" -e .
msg_ok "Installed Python deps"

msg_info "Initialise wger settings & database"
sudo -u "$WGER_USER" "${WGER_VENV}/bin/wger" create-settings --database-path "${WGER_DB_DIR}/database.sqlite"

sed -i "s#home/wger/src/media#home/wger/media#g" "${WGER_SRC}/settings.py"
sed -i "/MEDIA_ROOT = '\/home\/wger\/media'/a STATIC_ROOT = '${WGER_STATIC//\//\\/}'" "${WGER_SRC}/settings.py"

sudo -u "$WGER_USER" "${WGER_VENV}/bin/wger" bootstrap

sudo -u "$WGER_USER" "${WGER_VENV}/bin/python" manage.py collectstatic --noinput

echo "${RELEASE}" >/opt/wger_version.txt
msg_ok "Finished setting up wger"

msg_info "Configuring Apache (mod_wsgi)"
a2enmod wsgi >/dev/null 2>&1 || true

cat <<EOF >/etc/apache2/sites-available/wger.conf
<Directory ${WGER_SRC}>
    <Files wsgi.py>
        Require all granted
    </Files>
</Directory>

<VirtualHost *:80>
    # Run Django in the project's venv
    WSGIApplicationGroup %{GLOBAL}
    WSGIDaemonProcess wger python-home=${WGER_VENV} python-path=${WGER_SRC}
    WSGIProcessGroup wger
    WSGIScriptAlias / ${WGER_SRC}/wger/wsgi.py
    WSGIPassAuthorization On

    Alias /static/ ${WGER_STATIC}/
    <Directory ${WGER_STATIC}>
        Require all granted
    </Directory>

    Alias /media/ ${WGER_MEDIA}/
    <Directory ${WGER_MEDIA}>
        Require all granted
    </Directory>

    ErrorLog /var/log/apache2/wger-error.log
    CustomLog /var/log/apache2/wger-access.log combined
</VirtualHost>
EOF

$STD a2dissite 000-default.conf
$STD a2ensite wger
systemctl restart apache2
msg_ok "Apache configured"

msg_info "Creating wger CLI Service (optional)"
cat <<EOF >/etc/systemd/system/wger.service
[Unit]
Description=wger Service (CLI)
After=network.target

[Service]
Type=simple
User=${WGER_USER}
WorkingDirectory=${WGER_SRC}
ExecStart=${WGER_VENV}/bin/wger start -a 0.0.0.0 -p 3000
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now wger
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
rm -rf "$temp_dir"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
$STD apt-get -y clean
msg_ok "Cleaned"

motd_ssh
customize
