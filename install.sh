#!/usr/bin/env bash
set -euo pipefail

# Idempotent installer for socks-vpn
# - Installs scripts and units
# - Preserves existing config/password files
# - Restarts running service

log() { echo "[socks-vpn installer] $*"; }
die() { echo "ERROR: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

if [[ $EUID -ne 0 ]]; then
  die "Permission denied: this script must be run as root."
fi

SRC_DIR=$(cd "$(dirname "$0")" && pwd)
BIN_SRC="$SRC_DIR/bin"
UNIT_SRC="$SRC_DIR/systemd"
DESKTOP_SRC="$SRC_DIR/desktop/socks-vpn-tray.desktop"
POLKIT_SRC="$SRC_DIR/polkit/50-socks-vpn.rules"
CONFIG_SRC="$SRC_DIR/config"
GROUP_NAME="socks-vpn"

SYSTEMD_DIR=/etc/systemd/system
POLKIT_DIR=/etc/polkit-1/rules.d
DESKTOP_DIR=/usr/share/applications
CONFIG_DIR=/usr/local/etc

BIN_DST=/usr/local/bin/socks-vpn-control
TRAY_DST=/usr/local/bin/socks-vpn-tray
CONF_DST="$CONFIG_DIR/ssh-socks.conf"
PASS_DST="$CONFIG_DIR/ssh-socks.pass"
POLKIT_DST="$POLKIT_DIR/50-socks-vpn.rules"
DESKTOP_DST="$DESKTOP_DIR/socks-vpn-tray.desktop"

is_active="$(systemctl is-active socks-vpn.service 2>/dev/null || true)"
if [[ "$is_active" == "active" ]]; then
  log "socks-vpn.service is currently active, stopping for installation..."
  systemctl stop socks-vpn.service
fi

log "Checking required commands"
need systemctl
need ssh
need sshpass
need badvpn-tun2socks
need python3

if ! getent group "$GROUP_NAME" >/dev/null; then
  log "Creating system group $GROUP_NAME"
  groupadd --system "$GROUP_NAME"
else
  log "Group $GROUP_NAME already exists"
fi

log "Installing"
install -d "$CONFIG_DIR" "$SYSTEMD_DIR" "$POLKIT_DIR" "$DESKTOP_DIR"
install -m 0700 "$BIN_SRC/socks-vpn-control" "$BIN_DST"
install -m 0755 "$BIN_SRC/socks-vpn-tray" "$TRAY_DST"
install -m 0644 "$UNIT_SRC/socks-vpn.service" "$SYSTEMD_DIR/socks-vpn.service"
install -m 0644 "$UNIT_SRC/socks-vpn-server.service" "$SYSTEMD_DIR/socks-vpn-server.service"
install -m 0644 "$POLKIT_SRC" "$POLKIT_DST"
install -m 0644 "$DESKTOP_SRC" "$DESKTOP_DST"

if [[ -f "$CONF_DST" ]]; then
  log "Keeping existing config at $CONF_DST"
else
  install -m 0644 "$CONFIG_SRC/ssh-socks.conf" "$CONF_DST"
  log "Installed new config to $CONF_DST"
fi

if [[ -f "$PASS_DST" ]]; then
  log "Keeping existing password file at $PASS_DST"
else
  install -m 0400 "$CONFIG_SRC/ssh-socks.pass" "$PASS_DST"
  log "Created password file at $PASS_DST"
fi

log "Reloading systemd units"
systemctl daemon-reload
# we don't enable the units by default
if [[ "$is_active" == "active" ]]; then
  log "Starting socks-vpn.service"
  systemctl start socks-vpn.service
fi

active_after="$(systemctl is-active socks-vpn.service 2>/dev/null || true)"
server_after="$(systemctl is-active socks-vpn-server.service 2>/dev/null || true)"

log "socks-vpn.service status: ${active_after:-unknown}"
log "socks-vpn-server.service status: ${server_after:-unknown}"
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$DESKTOP_DIR" || true
  log "Updated desktop database"
fi

log "Done."
