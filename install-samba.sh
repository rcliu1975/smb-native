#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

SMB_USER=""
SMB_PASSWORD=""
SHARE_NAME=""
SHARE_DIR=""
WORKGROUP="WORKGROUP"
BACKUP_SUFFIX="${BACKUP_SUFFIX:-codex-$(date +%Y%m%d-%H%M%S)}"
SMB_CONF_PATH="/etc/samba/smb.conf"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_PATH="$SCRIPT_DIR/smb.conf.template"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_non_empty() {
  local name="$1"
  local value="$2"
  if [[ -z "$value" ]]; then
    echo "Missing required value: $name" >&2
    exit 1
  fi
}

resolve_smb_user() {
  local candidate=""

  if [[ -n "${SUDO_USER:-}" ]]; then
    candidate="$SUDO_USER"
  else
    candidate="$(logname 2>/dev/null || true)"
  fi

  require_non_empty SMB_USER "$candidate"

  if [[ "$candidate" == "root" ]]; then
    echo "Refusing to configure SMB for root; run with sudo from the account you want to share." >&2
    exit 1
  fi

  SMB_USER="$candidate"
}

resolve_share_settings() {
  local passwd_entry=""
  local home_dir=""

  passwd_entry="$(getent passwd "$SMB_USER" || true)"
  require_non_empty PASSWD_ENTRY "$passwd_entry"

  IFS=: read -r _ _ _ _ _ home_dir _ <<< "$passwd_entry"
  require_non_empty SHARE_DIR "$home_dir"

  SHARE_NAME="$SMB_USER"
  SHARE_DIR="$home_dir"
}

ensure_share_dir() {
  if [[ -d "$SHARE_DIR" ]]; then
    return
  fi

  if [[ -e "$SHARE_DIR" ]]; then
    echo "Share path exists but is not a directory: $SHARE_DIR" >&2
    exit 1
  fi

  install -d -m 2775 -o "$SMB_USER" -g "$SMB_USER" "$SHARE_DIR"
}

prompt_for_password() {
  local password=""
  local confirm=""

  if [[ ! -t 0 ]]; then
    echo "No interactive terminal available; run this script from a terminal." >&2
    exit 1
  fi

  read -r -s -p "Enter Samba password for $SMB_USER: " password
  echo
  read -r -s -p "Confirm Samba password: " confirm
  echo

  if [[ "$password" != "$confirm" ]]; then
    echo "Passwords did not match." >&2
    exit 1
  fi

  SMB_PASSWORD="$password"
  require_non_empty SMB_PASSWORD "$SMB_PASSWORD"
}

require_command apt-get
require_command systemctl
require_command getent
require_command install
require_command cp
require_command sed

resolve_smb_user
resolve_share_settings
prompt_for_password

if ! getent passwd "$SMB_USER" >/dev/null; then
  echo "Unix user does not exist: $SMB_USER" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y samba

ensure_share_dir

if [[ -f "$SMB_CONF_PATH" ]]; then
  cp "$SMB_CONF_PATH" "${SMB_CONF_PATH}.${BACKUP_SUFFIX}.bak"
fi

sed \
  -e "s|__WORKGROUP__|$WORKGROUP|g" \
  -e "s|__SHARE_NAME__|$SHARE_NAME|g" \
  -e "s|__SHARE_DIR__|$SHARE_DIR|g" \
  -e "s|__SMB_USER__|$SMB_USER|g" \
  "$TEMPLATE_PATH" >"$SMB_CONF_PATH"

printf '%s\n%s\n' "$SMB_PASSWORD" "$SMB_PASSWORD" | smbpasswd -s -a "$SMB_USER"

testparm -s >/dev/null
systemctl enable --now smbd nmbd
systemctl restart smbd nmbd

HOST_IPS="$(hostname -I 2>/dev/null | xargs || true)"

echo "Samba is configured."
echo "Share directory: $SHARE_DIR"
echo "Share name: $SHARE_NAME"
echo "Username: $SMB_USER"
if [[ -n "$HOST_IPS" ]]; then
  echo "Host IP(s): $HOST_IPS"
  echo "Windows: \\\\${HOST_IPS%% *}\\$SHARE_NAME"
  echo "macOS/Linux: smb://${HOST_IPS%% *}/$SHARE_NAME"
fi
