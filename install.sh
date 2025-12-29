#!/usr/bin/env bash
set -euo pipefail

log() { echo "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

if [[ $EUID -ne 0 ]]; then
  die "Permission denied: this script must be run as root."
fi

SRC_DIR=$(cd "$(dirname "$0")" && pwd)

BIN_SRC="$SRC_DIR/bin"
UNIT_SRC="$SRC_DIR/systemd/socks-vpn.service"
DESKTOP_SRC="$SRC_DIR/desktop/socks-vpn-tray.desktop"
POLKIT_SRC="$SRC_DIR/polkit/50-socks-vpn.rules"
CONFIG_SRC="$SRC_DIR/config/socks-vpn.conf"

GROUP_NAME="socks-vpn"

LIB_DIR=/usr/lib/socks-vpn
SYSTEMD_DIR=/usr/lib/systemd/system
DESKTOP_DIR=/usr/share/applications
POLKIT_DIR=/usr/share/polkit-1/rules.d
CONFIG_DIR=/etc
BIN_DIR=/usr/bin

SYSTEMD_DST="$SYSTEMD_DIR/socks-vpn.service"
DESKTOP_DST="$DESKTOP_DIR/socks-vpn-tray.desktop"
POLKIT_DST="$POLKIT_DIR/50-socks-vpn.rules"
CONF_DST="$CONFIG_DIR/socks-vpn.conf"

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
install -d "$CONFIG_DIR" "$SYSTEMD_DIR" "$POLKIT_DIR" "$DESKTOP_DIR" "$LIB_DIR"
install -d "$BIN_DIR"

for script in "$BIN_SRC"/*; do
  script_name=$(basename "$script")
  install -m 0755 "$script" "$LIB_DIR/$script_name"
done

# user-facing symlinks
ln -sf "$LIB_DIR/socks-vpn-control" "$BIN_DIR/socks-vpn-control"
ln -sf "$LIB_DIR/socks-vpn-tray" "$BIN_DIR/socks-vpn-tray"

install -m 0644 "$UNIT_SRC" "$SYSTEMD_DST"
install -m 0644 "$POLKIT_SRC" "$POLKIT_DST"
install -m 0644 "$DESKTOP_SRC" "$DESKTOP_DST"

if [[ -f "$CONF_DST" ]]; then
  log "Keeping existing config at $CONF_DST"
else
  install -m 0644 "$CONFIG_SRC" "$CONF_DST"
  log "Installed new config to $CONF_DST"
fi

PASS_DST="$CONFIG_DIR/socks-vpn.pass"
if [[ -f "$PASS_DST" ]]; then
  log "Keeping existing password file at $PASS_DST"
else
  install -m 0600 /dev/null "$PASS_DST"
  log "Created empty password file at $PASS_DST (fill it or switch to key auth)."
fi

log "Reloading systemd units"
systemctl daemon-reload
# we don't enable the units by default
if [[ "$is_active" == "active" ]]; then
  log "Starting socks-vpn.service"
  systemctl start socks-vpn.service
fi

active_after="$(systemctl is-active socks-vpn.service 2>/dev/null || true)"

log "socks-vpn.service status: ${active_after:-unknown}"
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$DESKTOP_DIR" || true
  log "Updated desktop database"
fi

log "Done."
