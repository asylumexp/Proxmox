#!/usr/bin/env bash

# Copyright (c) 2021-2026 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

source /dev/stdin <<<$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/api.func)

function header_info {
  cat <<"EOF"
                                      ____  _ __  ___                                        
                                    / __ \(_)  |/  /___  _  __                              
                                   / /_/ / / /|_/ / __ \| |/_/                              
                                  / ____/ / /  / / /_/ />  <                                
    __  __                       /_/_  /_/_/  /_/\____/_/|_|              __     ____  _____
   / / / /___  ____ ___  ___     /   |  __________(_)____/ /_____ _____  / /_   / __ \/ ___/
  / /_/ / __ \/ __ `__ \/ _ \   / /| | / ___/ ___/ / ___/ __/ __ `/ __ \/ __/  / / / /\__ \ 
 / __  / /_/ / / / / / /  __/  / ___ |(__  |__  ) (__  ) /_/ /_/ / / / / /_   / /_/ /___/ / 
/_/ /_/\____/_/ /_/ /_/\___/  /_/  |_/____/____/_/____/\__/\__,_/_/ /_/\__/   \____//____/  
                                                                                            
EOF
}
clear
header_info
echo -e "Loading..."
RANDOM_UUID="$(cat /proc/sys/kernel/random/uuid)"
METHOD=""
NSAPP="pimox-haos-vm"
var_os="pimox-haos"
var_version=" "
DISK_SIZE="32G"
GEN_MAC=$(echo '00 60 2f'$(od -An -N3 -t xC /dev/urandom) | sed -e 's/ /:/g' | tr '[:lower:]' '[:upper:]')
USEDID=$(pvesh get /cluster/resources --type vm --output-format yaml | egrep -i 'vmid' | awk '{print substr($2, 1, length($2)-0) }')
STABLE=$(curl -fsSL https://raw.githubusercontent.com/home-assistant/version/master/stable.json | grep "ova" | awk '{print substr($2, 2, length($2)-3) }')
BETA=$(curl -fsSL https://raw.githubusercontent.com/home-assistant/version/master/beta.json | grep "ova" | awk '{print substr($2, 2, length($2)-3) }')
DEV=$(curl -fsSL https://raw.githubusercontent.com/home-assistant/version/master/dev.json | grep "ova" | awk '{print substr($2, 2, length($2)-3) }')
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
HA=$(echo "\033[1;34m")
RD=$(echo "\033[01;31m")
BGN=$(echo "\033[4;92m")
GN=$(echo "\033[1;92m")
DGN=$(echo "\033[32m")
CL=$(echo "\033[m")
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
INFO=""
YWB="\033[1;33m"
CROSS="${RD}✗${CL}"
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
ARCH_CHECK=true
DIAGNOSTICS=true
shopt -s expand_aliases
alias die='EXIT=$? LINE=$LINENO error_exit'
trap die ERR
trap cleanup EXIT
trap 'post_update_to_api "failed" "INTERRUPTED"' SIGINT
trap 'post_update_to_api "failed" "TERMINATED"' SIGTERM
function error_handler() {
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
  post_update_to_api "failed" "${exit_code}"
  echo -e "\n$error_message\n"
  cleanup_vmid
}

function get_valid_nextid() {
  local try_id
  try_id=$(pvesh get /cluster/nextid)
  while true; do
    if [ -f "/etc/pve/qemu-server/${try_id}.conf" ] || [ -f "/etc/pve/lxc/${try_id}.conf" ]; then
      try_id=$((try_id + 1))
      continue
    fi
    if lvs --noheadings -o lv_name | grep -qE "(^|[-_])${try_id}($|[-_])"; then
      try_id=$((try_id + 1))
      continue
    fi
    break
  done
  echo "$try_id"
}

function cleanup_vmid() {
  if $(qm status $VMID &>/dev/null); then
    if [ "$(qm status $VMID | awk '{print $2}')" == "running" ]; then
      qm stop $VMID
    fi
    qm destroy $VMID
  fi
}
function cleanup() {
  local exit_code=$?
  popd >/dev/null
  if [[ "${POST_TO_API_DONE:-}" == "true" && "${POST_UPDATE_DONE:-}" != "true" ]]; then
    if [[ $exit_code -eq 0 ]]; then
      post_update_to_api "done" "none"
    else
      post_update_to_api "failed" "$exit_code"
    fi
  fi
  rm -rf $TEMP_DIR
}
TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null
if ! command -v whiptail &>/dev/null; then
  echo "Installing whiptail..."
  apt-get update &>/dev/null
  apt-get install -y whiptail &>/dev/null
fi

function msg_info() {
  local msg="$1"
  echo -ne "${TAB}${YW}${HOLD}${msg}${HOLD}"
}

function msg_ok() {
  local msg="$1"
  echo -e "${BFR}${CM}${GN}${msg}${CL}"
}

function msg_error() {
  local msg="$1"
  echo -e "${BFR}${CROSS}${RD}${msg}${CL}"
}

function check_root() {
  if [[ "$(id -u)" -ne 0 || $(ps -o comm= -p $PPID) == "sudo" ]]; then
    clear
    msg_error "Please run this script as root."
    echo -e "\nExiting..."
    sleep 2
    exit
  fi
}

# This function checks the version of Proxmox Virtual Environment (PVE) and exits if the version is not supported.
# Supported: Proxmox VE 8.0.x – 8.9.x, 9.0 and 9.1
pve_check() {
  local PVE_VER
  PVE_VER="$(pveversion | awk -F'/' '{print $2}' | awk -F'-' '{print $1}')"

  # Check for Proxmox VE 8.x: allow 8.0–8.9
  if [[ "$PVE_VER" =~ ^8\.([0-9]+) ]]; then
    local MINOR="${BASH_REMATCH[1]}"
    if ((MINOR < 0 || MINOR > 9)); then
      msg_error "This version of Proxmox VE is not supported."
      msg_error "Supported: Proxmox VE version 8.0 – 8.9"
      exit 1
    fi
    return 0
  fi

  # Check for Proxmox VE 9.x: allow 9.0 and 9.1
  if [[ "$PVE_VER" =~ ^9\.([0-9]+) ]]; then
    local MINOR="${BASH_REMATCH[1]}"
    if ((MINOR < 0 || MINOR > 1)); then
      msg_error "This version of Proxmox VE is not supported."
      msg_error "Supported: Proxmox VE version 9.0 – 9.1"
      exit 1
    fi
    return 0
  fi

  # All other unsupported versions
  msg_error "This version of Proxmox VE is not supported."
  msg_error "Supported versions: Proxmox VE 8.0 – 8.x or 9.0 – 9.1"
  exit 1
}

function arch_check() {
  local ARCH
  ARCH=$(dpkg --print-architecture)
  if [ "$ARCH" != "arm64" ]; then
    echo -e "\n This script will not work on AMD64! \n"
    echo -e "Exiting..."
    sleep 2
    exit 1
  fi
}

function msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
}
function msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}
function msg_error() {
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

function default_settings() {
  METHOD="default"
  echo -e "${DGN}Using HAOS Version: ${BGN}${STABLE}${CL}"
  BRANCH=${STABLE}
  VMID=$(get_valid_nextid)
  echo -e "${DGN}Using Virtual Machine ID: ${BGN}$VMID${CL}"
  echo -e "${DGN}Using Hostname: ${BGN}haos${STABLE}${CL}"
  HN=haos${STABLE}
  echo -e "${DGN}Allocated Cores: ${BGN}2${CL}"
  CORE_COUNT="2"
  echo -e "${DGN}Allocated RAM: ${BGN}4096${CL}"
  RAM_SIZE="4096"
  echo -e "${DGN}Using Bridge: ${BGN}vmbr0${CL}"
  BRG="vmbr0"
  echo -e "${DGN}Using MAC Address: ${BGN}$GEN_MAC${CL}"
  MAC=$GEN_MAC
  echo -e "${DGN}Using VLAN: ${BGN}Default${CL}"
  VLAN=""
  echo -e "${DGN}Using Interface MTU Size: ${BGN}Default${CL}"
  MTU=""
  echo -e "${DGN}Start VM when completed: ${BGN}yes${CL}"
  START_VM="yes"
  echo -e "${BL}Creating a HAOS VM using the above default settings${CL}"
}
function advanced_settings() {
  METHOD="advanced"
  BRANCH=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "HAOS VERSION" --radiolist "Choose Version" --cancel-button Exit-Script 10 58 3 \
    "$STABLE" "Stable" ON \
    "$BETA" "Beta" OFF \
    "$DEV" "Dev" OFF \
    3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then echo -e "${DGN}Using HAOS Version: ${BGN}$BRANCH${CL}"; fi
  [ -z "${VMID:-}" ] && VMID=$(get_valid_nextid)
  VMID=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Virtual Machine ID" 8 58 $VMID --title "VIRTUAL MACHINE ID" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ -z $VMID ]; then
    VMID="$VMID"
    echo -e "${DGN}Virtual Machine: ${BGN}$VMID${CL}"
  else
    if echo "$USEDID" | egrep -q "$VMID"; then
      echo -e "\n🚨  ${RD}ID $VMID is already in use${CL} \n"
      echo -e "Exiting Script \n"
      sleep 2
      exit
    else
      if [ $exitstatus = 0 ]; then echo -e "${DGN}Virtual Machine ID: ${BGN}$VMID${CL}"; fi
    fi
  fi
  VM_NAME=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Hostname" 8 58 haos${BRANCH} --title "HOSTNAME" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ -z $VM_NAME ]; then
    HN="haos${BRANCH}"
    echo -e "${DGN}Using Hostname: ${BGN}$HN${CL}"
  else
    if [ $exitstatus = 0 ]; then
      HN=$(echo ${VM_NAME,,} | tr -d ' ')
      echo -e "${DGN}Using Hostname: ${BGN}$HN${CL}"
    fi
  fi
  CORE_COUNT=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Allocate CPU Cores" 8 58 2 --title "CORE COUNT" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ -z $CORE_COUNT ]; then
    CORE_COUNT="2"
    echo -e "${DGN}Allocated Cores: ${BGN}$CORE_COUNT${CL}"
  else
    if [ $exitstatus = 0 ]; then echo -e "${DGN}Allocated Cores: ${BGN}$CORE_COUNT${CL}"; fi
  fi
  RAM_SIZE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Allocate RAM in MiB" 8 58 4096 --title "RAM" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ -z $RAM_SIZE ]; then
    RAM_SIZE="4096"
    echo -e "${DGN}Allocated RAM: ${BGN}$RAM_SIZE${CL}"
  else
    if [ $exitstatus = 0 ]; then echo -e "${DGN}Allocated RAM: ${BGN}$RAM_SIZE${CL}"; fi
  fi
  BRG=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a Bridge" 8 58 vmbr0 --title "BRIDGE" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ -z $BRG ]; then
    BRG="vmbr0"
    echo -e "${DGN}Using Bridge: ${BGN}$BRG${CL}"
  else
    if [ $exitstatus = 0 ]; then echo -e "${DGN}Using Bridge: ${BGN}$BRG${CL}"; fi
  fi
  MAC1=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a MAC Address" 8 58 $GEN_MAC --title "MAC ADDRESS" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ -z $MAC1 ]; then
    MAC="$GEN_MAC"
    echo -e "${DGN}Using MAC Address: ${BGN}$MAC${CL}"
  else
    if [ $exitstatus = 0 ]; then
      MAC="$MAC1"
      echo -e "${DGN}Using MAC Address: ${BGN}$MAC1${CL}"
    fi
  fi
  VLAN1=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a Vlan(leave blank for default)" 8 58 --title "VLAN" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    if [ -z $VLAN1 ]; then
      VLAN1="Default" VLAN=""
      echo -e "${DGN}Using Vlan: ${BGN}$VLAN1${CL}"
    else
      VLAN=",tag=$VLAN1"
      echo -e "${DGN}Using Vlan: ${BGN}$VLAN1${CL}"
    fi
  fi
  MTU1=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Interface MTU Size (leave blank for default)" 8 58 --title "MTU SIZE" --cancel-button Exit-Script 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    if [ -z $MTU1 ]; then
      MTU1="Default" MTU=""
      echo -e "${DGN}Using Interface MTU Size: ${BGN}$MTU1${CL}"
    else
      MTU=",mtu=$MTU1"
      echo -e "${DGN}Using Interface MTU Size: ${BGN}$MTU1${CL}"
    fi
  fi
  if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "START VIRTUAL MACHINE" --yesno "Start VM when completed?" 10 58); then
    echo -e "${DGN}Start VM when completed: ${BGN}yes${CL}"
    START_VM="yes"
  else
    echo -e "${DGN}Start VM when completed: ${BGN}no${CL}"
    START_VM="no"
  fi
  if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "ADVANCED SETTINGS COMPLETE" --yesno "Ready to create HAOS ${BRANCH} VM?" --no-button Do-Over 10 58); then
    echo -e "${RD}Creating a HAOS VM using the above advanced settings${CL}"
  else
    clear
    header_info
    echo -e "${RD}Using Advanced Settings${CL}"
    advanced_settings
  fi
}
function START_SCRIPT() {
  if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "SETTINGS" --yesno "Use Default Settings?" --no-button Advanced 10 58); then
    clear
    header_info
    echo -e "${BL}Using Default Settings${CL}"
    default_settings
  else
    clear
    header_info
    echo -e "${RD}Using Advanced Settings${CL}"
    advanced_settings
  fi
}
arch_check
START_SCRIPT
post_to_api_vm
while read -r line; do
  TAG=$(echo $line | awk '{print $1}')
  TYPE=$(echo $line | awk '{printf "%-10s", $2}')
  FREE=$(echo $line | numfmt --field 4-6 --from-unit=K --to=iec --format %.2f | awk '{printf( "%9sB", $6)}')
  ITEM="  Type: $TYPE Free: $FREE "
  OFFSET=2
  if [[ $((${#ITEM} + $OFFSET)) -gt ${MSG_MAX_LENGTH:-} ]]; then
    MSG_MAX_LENGTH=$((${#ITEM} + $OFFSET))
  fi
  STORAGE_MENU+=("$TAG" "$ITEM" "OFF")
done < <(pvesm status -content images | awk 'NR>1')
if [ $((${#STORAGE_MENU[@]} / 3)) -eq 0 ]; then
  echo -e "'Disk image' needs to be selected for at least one storage location."
  die "Unable to detect valid storage location."
elif [ $((${#STORAGE_MENU[@]} / 3)) -eq 1 ]; then
  STORAGE=${STORAGE_MENU[0]}
else
  while [ -z "${STORAGE:+x}" ]; do
    STORAGE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "Storage Pools" --radiolist \
      "Which storage pool would you like to use for the HAOS VM?\n\n" \
      16 $(($MSG_MAX_LENGTH + 23)) 6 \
      "${STORAGE_MENU[@]}" 3>&1 1>&2 2>&3)
  done
fi
msg_ok "Using ${CL}${BL}$STORAGE${CL} ${GN}for Storage Location."
msg_ok "Virtual Machine ID is ${CL}${BL}$VMID${CL}."
msg_info "Getting URL for Home Assistant ${BRANCH} Disk Image"
URL=https://github.com/home-assistant/operating-system/releases/download/${BRANCH}/haos_generic-aarch64-${BRANCH}.qcow2.xz
sleep 2
msg_ok "${CL}${BL}${URL}${CL}"
curl -f#SL -o "$(basename "$URL")" "$URL"
echo -en "\e[1A\e[0K"
FILE=$(basename $URL)
msg_ok "Downloaded ${CL}${BL}haos_generic-aarch64-${BRANCH}.qcow2.xz${CL}"
msg_info "Extracting Disk Image"
unxz $FILE
STORAGE_TYPE=$(pvesm status -storage $STORAGE | awk 'NR>1 {print $2}')
case $STORAGE_TYPE in
nfs | dir)
  DISK_EXT=".qcow2"
  DISK_REF="$VMID/"
  DISK_IMPORT="-format qcow2"
  ;;
*)
  DISK_EXT=""
  DISK_REF=""
  DISK_IMPORT="-format raw"
  ;;
esac
for i in {0,1}; do
  disk="DISK$i"
  eval DISK${i}=vm-${VMID}-disk-${i}${DISK_EXT:-}
  eval DISK${i}_REF=${STORAGE}:${DISK_REF:-}${!disk}
done
msg_ok "Extracted Disk Image"
msg_info "Creating HAOS VM"
qm create $VMID -bios ovmf -cores $CORE_COUNT -memory $RAM_SIZE -name $HN \
  -net0 virtio,bridge=$BRG,macaddr=$MAC$VLAN$MTU -onboot 1 -ostype l26 -scsihw virtio-scsi-pci
pvesm alloc $STORAGE $VMID $DISK0 64M 1>&/dev/null
qm importdisk $VMID ${FILE%.*} $STORAGE ${DISK_IMPORT:-} 1>&/dev/null
qm set $VMID \
  -efidisk0 ${DISK0_REF},efitype=4m,size=64M \
  -scsi0 ${DISK1_REF},size=32G >/dev/null
qm set $VMID \
  -boot order=scsi0 \
  -description "<div align='center'><a href='https://Helper-Scripts.com'><img src='https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/images/logo-81x112.png'/></a>

  # Home Assistant OS

  <a href='https://ko-fi.com/D1D7EP4GF'><img src='https://img.shields.io/badge/&#x2615;-Buy me a coffee-blue' /></a>
  </div>" >/dev/null
msg_ok "Created HAOS VM ${CL}${BL}(${HN})"
if [ "$START_VM" == "yes" ]; then
  msg_info "Starting Home Assistant OS VM"
  qm start $VMID
  msg_ok "Started Home Assistant OS VM"
fi
post_update_to_api "done" "none"
msg_ok "Completed successfully!\n"
