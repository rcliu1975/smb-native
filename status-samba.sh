#!/usr/bin/env bash
set -euo pipefail

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_command systemctl
require_command testparm

HOST_IPS="$(hostname -I 2>/dev/null | xargs || true)"

echo "smbd: $(systemctl is-active smbd 2>/dev/null || true)"
echo "nmbd: $(systemctl is-active nmbd 2>/dev/null || true)"

if [[ -n "$HOST_IPS" ]]; then
  echo "Host IP(s): $HOST_IPS"
fi

echo
echo "Configured shares:"
testparm -s 2>/dev/null | sed -n '/^\[/,/^$/p'
