#!/usr/bin/env bash
set -Eeuo pipefail

# Pin this to an immutable release or commit archive URL.
AI_WORKSTATION_ARCHIVE_URL="${AI_WORKSTATION_ARCHIVE_URL:-}"
AI_WORKSTATION_USER="${AI_WORKSTATION_USER:-harry}"

if [[ -z "$AI_WORKSTATION_ARCHIVE_URL" ]]; then
  echo "ERROR: set AI_WORKSTATION_ARCHIVE_URL to a pinned source archive." >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL "$AI_WORKSTATION_ARCHIVE_URL" -o "$tmp/ai-workstation.tar.gz"
tar -xzf "$tmp/ai-workstation.tar.gz" -C "$tmp"
package_dir="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d -print -quit)"
if [[ -z "$package_dir" || ! -x "$package_dir/stage-next-boot.sh" ]]; then
  echo "ERROR: archive does not contain the AI Workstation package." >&2
  exit 1
fi

AI_WORKSTATION_USER="$AI_WORKSTATION_USER" "$package_dir/stage-next-boot.sh"

echo "AI Workstation staged. Reboot to begin provisioning."
