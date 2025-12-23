#!/usr/bin/env bash
set -euo pipefail

# Idempotent installer for socks-vpn
# - Installs scripts and units
# - Preserves existing config/password files
# - Restarts running service

log() { echo "[socks-vpn installer] $*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

if [[ $EUID -ne 0 ]]; then
  die "Permission denied: this script must be run as root."
fi

is_active="$(systemctl is-active socks-vpn.service 2>/dev/null || true)"
if [[ "$is_active" == "active" ]]; then
  log "socks-vpn.service is currently active, stopting for installation..."
  systemctl stop socks-vpn.service
fi

SRC_DIR=$(cd "$(dirname "$0")" && pwd)
SYSTEMD_DIR=/etc/systemd/system
BIN_DST=/usr/local/bin/socks-vpn-control
CONF_DST=/usr/local/etc/ssh-socks.conf
PASS_DST=/usr/local/etc/ssh-socks.pass

log "Installing binaries and unit files"
install -m 0700 "$SRC_DIR/socks-vpn-control" "$BIN_DST"
install -d /usr/local/etc
install -d "$SYSTEMD_DIR"
install -m 0644 "$SRC_DIR/socks-vpn.service" "$SYSTEMD_DIR/socks-vpn.service"
install -m 0644 "$SRC_DIR/socks-vpn-server.service" "$SYSTEMD_DIR/socks-vpn-server.service"

if [[ -f "$CONF_DST" ]]; then
  log "Keeping existing config at $CONF_DST"
else
  install -m 0644 "$SRC_DIR/ssh-socks.conf" "$CONF_DST"
  log "Installed new config to $CONF_DST"
fi

if [[ -f "$PASS_DST" ]]; then
  log "Keeping existing password file at $PASS_DST"
else
  install -m 0400 "$SRC_DIR/ssh-socks.pass" "$PASS_DST"
  log "Created password file at $PASS_DST"
fi

log "Reloading systemd units"
systemctl daemon-reload
if [[ "$is_active" == "active" ]]; then
  log "Starting socks-vpn.service"
  systemctl start socks-vpn.service
fi

active_after="$(systemctl is-active socks-vpn.service 2>/dev/null || true)"
server_after="$(systemctl is-active socks-vpn-server.service 2>/dev/null || true)"

log "socks-vpn.service status: ${active_after:-unknown}"
log "socks-vpn-server.service status: ${server_after:-unknown}"
log "Done."
