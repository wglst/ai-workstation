#!/usr/bin/env bash
set -u

VERSION="0.4"
LOG_DIR="/var/log/ai-workstation"
REPORT_FILE="$LOG_DIR/report.txt"
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
    v="$(bash -lc "$version_cmd" 2>&1 | head -n 1)"
    pass "$label" "$v"
  else
    fail "$label" "not found"
  fi
}

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

if [[ -d /workspace/projects ]]; then
  pass "Workspace" "/workspace/projects"
else
  fail "Workspace" "missing"
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
  echo "SPEC_VERSION: $VERSION"
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
