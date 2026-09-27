#!/usr/bin/env bash
set -Eeuo pipefail

# Pin this to the exact released version/tag or immutable commit URL.
AI_WORKSTATION_INSTALL_URL="${AI_WORKSTATION_INSTALL_URL:-REPLACE_WITH_VERSIONED_RAW_INSTALL_URL}"
AI_WORKSTATION_VERIFY_URL="${AI_WORKSTATION_VERIFY_URL:-REPLACE_WITH_VERSIONED_RAW_VERIFY_URL}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL "$AI_WORKSTATION_INSTALL_URL" -o "$tmp/install.sh"
curl -fsSL "$AI_WORKSTATION_VERIFY_URL" -o "$tmp/verify.sh"
chmod +x "$tmp/install.sh" "$tmp/verify.sh"

"$tmp/install.sh"
