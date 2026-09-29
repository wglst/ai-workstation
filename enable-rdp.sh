#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "ERROR: run as root (or with sudo)." >&2
  exit 1
fi

TAILSCALE_IP="$(tailscale ip -4 2>/dev/null | head -n 1)"
if [[ ! "$TAILSCALE_IP" =~ ^100\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
  echo "ERROR: Tailscale is not authorized or has no IPv4 address." >&2
  echo "Run 'sudo tailscale up' first, then retry." >&2
  exit 1
fi

cp -a /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.before-ai-workstation
sed -i "/^\[Globals\]/,/^\[/{s|^port=.*|port=tcp://$TAILSCALE_IP:3389|;}" /etc/xrdp/xrdp.ini
systemctl restart xrdp

if ! ss -ltn | awk '{print $4}' | grep -qx "$TAILSCALE_IP:3389"; then
  echo "ERROR: XRDP did not bind to the Tailscale address." >&2
  exit 1
fi

echo "XRDP is available only at $TAILSCALE_IP:3389."
