#!/usr/bin/env bash
set -u

SPEC_VERSION="0.6"
LOG_DIR="/var/log/ai-workstation"
REPORT_FILE="$LOG_DIR/report.txt"
CONFIG_FILE="/etc/ai-workstation/config.env"
if [[ -r "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  . "$CONFIG_FILE"
fi
AI_WORKSTATION_USER="${AI_WORKSTATION_USER:-harry}"
mkdir -p "$LOG_DIR"

FAILURES=0
LINES=()

pass() {
  LINES+=("PASS  $(printf '%-22s' "$1") $2")
}

fail() {
  LINES+=("FAIL  $(printf '%-22s' "$1") $2")
  FAILURES=$((FAILURES + 1))
}

check_cmd() {
  local label="$1"
  local cmd="$2"
  local version_cmd="$3"
  if command -v "$cmd" >/dev/null 2>&1; then
    local v
    if v="$(bash -lc "$version_cmd" 2>&1)"; then
      pass "$label" "$(head -n 1 <<< "$v")"
    else
      fail "$label" "present but version check failed: $(head -n 1 <<< "$v")"
    fi
  else
    fail "$label" "not found"
  fi
}

# shellcheck source=/etc/os-release
. /etc/os-release
pass "Ubuntu" "${PRETTY_NAME:-unknown}"
pass "Architecture" "$(uname -m)"

check_cmd "Docker" docker "docker --version"
check_cmd "Docker Compose" docker "docker compose version"
check_cmd "Node.js" node "node --version"
check_cmd "npm" npm "npm --version"
check_cmd "Python" python3 "python3 --version"
check_cmd "pipx" pipx "pipx --version"
check_cmd "uv" uv "uv --version"
check_cmd "Git" git "git --version"
check_cmd "GitHub CLI" gh "gh --version"
check_cmd "Git LFS" git-lfs "git-lfs --version"
check_cmd "Codex CLI" codex "codex --version"
check_cmd "Claude Code" claude "claude --version"
check_cmd "Tailscale" tailscale "tailscale version"
check_cmd "ripgrep" rg "rg --version"
check_cmd "fd" fd "fd --version"
check_cmd "SQLite" sqlite3 "sqlite3 --version"
check_cmd "ShellCheck" shellcheck "shellcheck --version"
check_cmd "Zsh" zsh "zsh --version"
check_cmd "micro" micro "micro --version"
check_cmd "bat" bat "bat --version"
check_cmd "eza" eza "eza --version"
check_cmd "fzf" fzf "fzf --version"
check_cmd "VS Code" code "sudo -u '$AI_WORKSTATION_USER' code --version"
check_cmd "XFCE" xfce4-session "dpkg-query -W -f='\${Version}\\n' xfce4-session"
check_cmd "XRDP" xrdp "xrdp --version"

if command -v google-chrome >/dev/null 2>&1; then
  check_cmd "Browser" google-chrome "google-chrome --version"
elif command -v chromium-browser >/dev/null 2>&1; then
  check_cmd "Browser" chromium-browser "chromium-browser --version"
else
  fail "Browser" "not found"
fi

if systemctl is-active --quiet docker; then
  pass "Docker service" "active"
else
  fail "Docker service" "inactive"
fi

if systemctl is-active --quiet tailscaled; then
  pass "Tailscale service" "active"
else
  fail "Tailscale service" "inactive"
fi

if systemctl is-active --quiet xrdp; then
  pass "XRDP service" "active"
else
  fail "XRDP service" "inactive"
fi

if [[ -d /workspace/projects ]]; then
  pass "Workspace" "/workspace/projects"
else
  fail "Workspace" "missing"
fi

if id "$AI_WORKSTATION_USER" >/dev/null 2>&1; then
  pass "Desktop user" "$AI_WORKSTATION_USER"
else
  fail "Desktop user" "$AI_WORKSTATION_USER missing"
fi

for group in sudo docker; do
  if id -nG "$AI_WORKSTATION_USER" 2>/dev/null | tr ' ' '\n' | grep -qx "$group"; then
    pass "User group: $group" "$AI_WORKSTATION_USER"
  else
    fail "User group: $group" "$AI_WORKSTATION_USER not a member"
  fi
done

if sudo -u "$AI_WORKSTATION_USER" test -w /workspace/projects; then
  pass "Workspace writable" "$AI_WORKSTATION_USER"
else
  fail "Workspace writable" "$AI_WORKSTATION_USER cannot write"
fi

XRDP_PORT_LINE="$(awk '/^\[Globals\]/{section=1; next} /^\[/{section=0} section && /^port=/{print; exit}' /etc/xrdp/xrdp.ini)"
XRDP_LISTENERS="$(ss -ltnH | awk '$4 ~ /:3389$/ {print $4}')"
if [[ "$XRDP_PORT_LINE" == "port=tcp://127.0.0.1:3389" ]]; then
  if grep -qx '127.0.0.1:3389' <<< "$XRDP_LISTENERS"; then
    pass "XRDP binding" "localhost only; run ai-workstation-enable-rdp after Tailscale login"
  else
    fail "XRDP binding" "config is localhost, listener is ${XRDP_LISTENERS:-missing}"
  fi
elif [[ "$XRDP_PORT_LINE" == port=tcp://100.*:3389 ]]; then
  EXPECTED_LISTENER="${XRDP_PORT_LINE#port=tcp://}"
  if grep -qx "$EXPECTED_LISTENER" <<< "$XRDP_LISTENERS"; then
    pass "XRDP binding" "Tailscale only ($EXPECTED_LISTENER)"
  else
    fail "XRDP binding" "config is $EXPECTED_LISTENER, listener is ${XRDP_LISTENERS:-missing}"
  fi
else
  fail "XRDP binding" "unsafe or unexpected: ${XRDP_PORT_LINE:-missing}"
fi

if systemctl is-enabled --quiet unattended-upgrades; then
  pass "Security updates" "enabled"
else
  fail "Security updates" "disabled"
fi

ROOT_SHELL="$(getent passwd root | cut -d: -f7)"
if [[ "$ROOT_SHELL" == "$(command -v zsh 2>/dev/null)" ]]; then
  pass "Root shell" "$ROOT_SHELL"
else
  fail "Root shell" "$ROOT_SHELL"
fi

if [[ -d /root/.oh-my-zsh ]]; then
  pass "Oh My Zsh" "/root/.oh-my-zsh"
else
  fail "Oh My Zsh" "missing"
fi

{
  echo "AI WORKSTATION VERIFICATION"
  echo "==========================="
  echo
  echo "SPEC_VERSION: $SPEC_VERSION"
  echo "TIMESTAMP: $(date -Is)"
  echo
  printf '%s\n' "${LINES[@]}"
  echo
  if (( FAILURES == 0 )); then
    echo "RESULT: PASS"
  else
    echo "RESULT: FAIL ($FAILURES checks failed)"
  fi
  echo "INSTALL_LOG: $LOG_DIR/install.log"
} | tee "$REPORT_FILE"

chmod 0644 "$REPORT_FILE"

if (( FAILURES == 0 )); then
  exit 0
fi
exit 1
