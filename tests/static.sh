#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EXPECTED_VERSION="$(<VERSION)"
[[ "$EXPECTED_VERSION" == "0.6" ]]
grep -qx "SPEC_VERSION=\"$EXPECTED_VERSION\"" install.sh
grep -qx "SPEC_VERSION=\"$EXPECTED_VERSION\"" verify.sh
grep -q "AI Workstation v$EXPECTED_VERSION" README.md
grep -q "AI Workstation v$EXPECTED_VERSION staged" stage-next-boot.sh

for required in \
  install.sh verify.sh stage-next-boot.sh enable-rdp.sh wait-rdp-address.sh \
  bootstrap/bootstrap.sh bootstrap/first-boot-runner.sh; do
  [[ -f "$required" ]]
  bash -n "$required"
done

grep -q 'port=tcp://127.0.0.1:3389' install.sh
grep -q 'tailscale ip -4' enable-rdp.sh
grep -q 'AI_WORKSTATION_ARCHIVE_URL' bootstrap/bootstrap.sh
grep -q 'Ubuntu 24.04 LTS is required' install.sh
grep -q 'docker.list.ai-workstation-disabled' install.sh

if command -v shellcheck >/dev/null 2>&1; then
  find . -type f -name '*.sh' -print0 | xargs -0 shellcheck
fi

echo "AI Workstation static contract: PASS"
