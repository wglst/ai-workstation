#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "ERROR: run as root (or with sudo)." >&2
  exit 1
fi

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="/opt/ai-workstation"
STATE_DIR="/var/lib/ai-workstation"
UNIT="ai-workstation-firstboot.service"
AI_WORKSTATION_USER="${AI_WORKSTATION_USER:-harry}"

if [[ "$AI_WORKSTATION_USER" == "root" || ! "$AI_WORKSTATION_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
  echo "ERROR: invalid AI_WORKSTATION_USER: $AI_WORKSTATION_USER" >&2
  exit 1
fi

install -d -m 0755 "$DEST_DIR" "$STATE_DIR" /etc/ai-workstation
install -m 0755 "$SRC_DIR/install.sh" "$DEST_DIR/install.sh"
install -m 0755 "$SRC_DIR/verify.sh" "$DEST_DIR/verify.sh"
install -m 0755 "$SRC_DIR/enable-rdp.sh" "$DEST_DIR/enable-rdp.sh"
install -m 0755 "$SRC_DIR/wait-rdp-address.sh" "$DEST_DIR/wait-rdp-address.sh"
install -m 0755 "$SRC_DIR/bootstrap/first-boot-runner.sh" "$DEST_DIR/first-boot-runner.sh"
printf 'AI_WORKSTATION_USER=%q\n' "$AI_WORKSTATION_USER" > /etc/ai-workstation/config.env
chmod 0644 /etc/ai-workstation/config.env

cat > "/etc/systemd/system/$UNIT" <<'UNITEOF'
[Unit]
Description=AI Workstation one-time first-boot provisioner
Wants=network-online.target
After=network-online.target
ConditionPathExists=!/var/lib/ai-workstation/provisioned

[Service]
Type=oneshot
ExecStart=/opt/ai-workstation/first-boot-runner.sh
TimeoutStartSec=0
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
UNITEOF

systemctl daemon-reload
systemctl enable "$UNIT"

echo
printf 'AI Workstation v0.6 staged for desktop user %s.\n' "$AI_WORKSTATION_USER"
printf 'Next boot will provision, verify, mark success, and reboot once more automatically.\n'
printf 'After the final reboot, inspect:\n'
printf '  /var/log/ai-workstation/install.log\n'
printf '  /var/log/ai-workstation/report.txt\n'
printf '  /var/log/ai-workstation/first-boot.log\n'
printf '\nStart the process with:\n  reboot\n'
