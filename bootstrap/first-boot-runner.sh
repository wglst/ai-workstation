#!/usr/bin/env bash
set -Eeuo pipefail

LOG_DIR="/var/log/ai-workstation"
STATE_DIR="/var/lib/ai-workstation"
UNIT="ai-workstation-firstboot.service"

mkdir -p "$LOG_DIR" "$STATE_DIR"
exec > >(tee -a "$LOG_DIR/first-boot.log") 2>&1

fail() {
  rc=$?
  echo "FIRST_BOOT_RESULT=FAIL"
  echo "EXIT_CODE=$rc"
  echo "FAILED_AT=$(date -Is)"
  exit "$rc"
}
trap fail ERR

echo "=== AI Workstation first boot started: $(date -Is) ==="

cd /opt/ai-workstation
./install.sh

# install.sh already runs verification, but verify once more explicitly as
# the acceptance gate for the one-time boot transaction.
./verify.sh | tee "$LOG_DIR/final-verification.txt"

touch "$STATE_DIR/provisioned"
systemctl disable "$UNIT" || true

echo "FIRST_BOOT_RESULT=PASS"
echo "COMPLETED_AT=$(date -Is)"
echo "Provisioning complete. Scheduling one final reboot in 10 seconds."

# Schedule reboot after this oneshot exits cleanly.
systemd-run --unit=ai-workstation-final-reboot --on-active=10s \
  /usr/bin/systemctl reboot >/dev/null
