#!/usr/bin/env bash
set -Eeuo pipefail

XRDP_ADDRESS="$(awk '/^\[Globals\]/{section=1; next} /^\[/{section=0} section && /^port=/{sub(/^port=tcp:\/\//, ""); sub(/:3389$/, ""); print; exit}' /etc/xrdp/xrdp.ini)"
if [[ -z "$XRDP_ADDRESS" || "$XRDP_ADDRESS" == "127.0.0.1" ]]; then
  exit 0
fi

for _ in $(seq 1 60); do
  if ip -4 address show | grep -Fq "inet $XRDP_ADDRESS/"; then
    exit 0
  fi
  sleep 1
done

echo "ERROR: XRDP address $XRDP_ADDRESS did not appear within 60 seconds." >&2
exit 1
