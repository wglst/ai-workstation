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

install -d -m 0755 "$DEST_DIR" "$STATE_DIR"
install -m 0755 "$SRC_DIR/install.sh" "$DEST_DIR/install.sh"
install -m 0755 "$SRC_DIR/verify.sh" "$DEST_DIR/verify.sh"
install -m 0755 "$SRC_DIR/bootstrap/first-boot-runner.sh" "$DEST_DIR/first-boot-runner.sh"

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
printf 'AI Workstation v0.5 staged.\n'
printf 'Next boot will provision, verify, mark success, and reboot once more automatically.\n'
printf 'After the final reboot, inspect:\n'
printf '  /var/log/ai-workstation/install.log\n'
printf '  /var/log/ai-workstation/report.txt\n'
printf '  /var/log/ai-workstation/first-boot.log\n'
printf '\nStart the process with:\n  reboot\n'
