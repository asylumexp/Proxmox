#!/usr/bin/env bash

# Copyright (c) 2021-2025 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
# License: MIT
# Source: https://www.djangoproject.com/

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get update -y
$STD apt-get install -y \
  sudo \
  curl \
  gnupg \
  python3 \
  python3-pip \
  python3-dev \
  build-essential \
  libssl-dev \
  libffi-dev \
  libmysqlclient-dev \
  libjpeg-dev \
  zlib1g-dev \
  libpq-dev
msg_ok "Installed Dependencies"

msg_info "Installing Django"
pip3 install --upgrade pip
pip3 install django
msg_ok "Installed Django"

msg_info "Creating a Django Project"
read -r -p "Enter a project name: " PROJECT_NAME
django-admin startproject "$PROJECT_NAME"
cd "$PROJECT_NAME"
msg_ok "Django Project '$PROJECT_NAME' Created"

msg_info "Setting up MySQL Database for Django"
read -r -p "Would you like to set up a MySQL database for the Django project? <y/N> " prompt
if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
  msg_info "Installing MySQL Client"
  pip3 install mysqlclient
  msg_ok "Installed MySQL Client"

  read -r -p "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
  read -r -p "Enter MySQL database name: " DB_NAME
  read -r -p "Enter MySQL user for Django: " DB_USER
  read -r -p "Enter MySQL password for user $DB_USER: " DB_PASS

  msg_info "Creating Database in MySQL"
  mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE $DB_NAME;"
  mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
  mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
  mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"
  msg_ok "Database '$DB_NAME' Created and User '$DB_USER' Set"

  msg_info "Configuring Django to use MySQL"
  sed -i "s/ENGINE: 'django.db.backends.sqlite3'/ENGINE: 'django.db.backends.mysql'/g" "$PROJECT_NAME/settings.py"
  sed -i "s/NAME: BASE_DIR \/ 'db.sqlite3'/NAME: '$DB_NAME'/g" "$PROJECT_NAME/settings.py"
  echo -e "USER: '$DB_USER'\nPASSWORD: '$DB_PASS'\nHOST: 'localhost'\nPORT: ''" >> "$PROJECT_NAME/settings.py"
  msg_ok "Django Configured to Use MySQL"
fi

msg_info "Migrating Database"
python3 manage.py migrate
msg_ok "Database Migrated"

msg_info "Starting Django Development Server"
python3 manage.py runserver 0.0.0.0:8000 &
msg_ok "Django Server Started"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
