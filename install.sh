#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="0.4"
LOG_DIR="/var/log/ai-workstation"
LOG_FILE="$LOG_DIR/install.log"
REPORT_FILE="$LOG_DIR/report.txt"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chmod 0644 "$LOG_FILE"

exec > >(tee -a "$LOG_FILE") 2>&1

on_error() {
  local rc=$?
  {
    echo "AI WORKSTATION INSTALLATION"
    echo "==========================="
    echo
    echo "VERSION: $VERSION"
    echo "RESULT: FAIL"
    echo "FAILED_COMMAND: ${BASH_COMMAND}"
    echo "EXIT_CODE: $rc"
    echo "LOG: $LOG_FILE"
  } > "$REPORT_FILE"
  chmod 0644 "$REPORT_FILE"
  exit "$rc"
}
trap on_error ERR

if [[ "${EUID}" -ne 0 ]]; then
  echo "ERROR: install.sh must run as root." >&2
  exit 1
fi

. /etc/os-release
if [[ "${ID:-}" != "ubuntu" ]]; then
  echo "ERROR: Ubuntu is required. Detected: ${PRETTY_NAME:-unknown}" >&2
  exit 1
fi

echo "==> AI Workstation v$VERSION"
echo "==> OS: ${PRETTY_NAME}"
echo "==> Architecture: $(dpkg --print-architecture)"
echo "==> Started: $(date -Is)"

export DEBIAN_FRONTEND=noninteractive

echo "==> Updating base system"
apt-get update
apt-get -y upgrade

echo "==> Installing base packages"
apt-get install -y \
  ca-certificates curl wget gnupg lsb-release apt-transport-https \
  git jq unzip zip tar xz-utils build-essential \
  python3 python3-pip python3-venv pipx \
  ripgrep fd-find sqlite3 shellcheck zsh fzf \
  micro bat eza openssh-client openssh-server

# Ubuntu names these binaries differently.
ln -sf "$(command -v fdfind)" /usr/local/bin/fd
ln -sf "$(command -v batcat)" /usr/local/bin/bat

echo "==> Installing Docker Engine from Docker's Ubuntu repository"
for pkg in docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc; do
  dpkg -s "$pkg" >/dev/null 2>&1 && apt-get remove -y "$pkg" || true
done

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

echo "==> Installing Node.js 22"
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

echo "==> Installing GitHub CLI"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  > /etc/apt/sources.list.d/github-cli.list
apt-get update
apt-get install -y gh

echo "==> Installing uv"
curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

echo "==> Installing Tailscale"
curl -fsSL https://tailscale.com/install.sh | sh
systemctl enable --now tailscaled

echo "==> Installing Codex CLI"
npm install -g @openai/codex

echo "==> Installing Claude Code"
npm install -g @anthropic-ai/claude-code

echo "==> Installing Oh My Zsh for root"
if [[ ! -d /root/.oh-my-zsh ]]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
chsh -s "$(command -v zsh)" root

echo "==> Creating workspace"
mkdir -p /workspace/projects
chmod 0775 /workspace /workspace/projects

echo "==> Installing verification command"
install -m 0755 "$(dirname "$0")/verify.sh" /usr/local/bin/verify-ai-workstation

echo "==> Running verification"
/usr/local/bin/verify-ai-workstation

echo "==> Finished: $(date -Is)"
echo "==> Full log: $LOG_FILE"
echo "==> Verification report: $REPORT_FILE"
