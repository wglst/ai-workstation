#!/usr/bin/env bash
set -Eeuo pipefail

SPEC_VERSION="0.6"
LOG_DIR="/var/log/ai-workstation"
LOG_FILE="$LOG_DIR/install.log"
REPORT_FILE="$LOG_DIR/report.txt"
CONFIG_FILE="/etc/ai-workstation/config.env"

if [[ -r "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  . "$CONFIG_FILE"
fi
AI_WORKSTATION_USER="${AI_WORKSTATION_USER:-harry}"

if [[ "$AI_WORKSTATION_USER" == "root" || ! "$AI_WORKSTATION_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
  echo "ERROR: invalid AI_WORKSTATION_USER: $AI_WORKSTATION_USER" >&2
  exit 1
fi

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
    echo "VERSION: $SPEC_VERSION"
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

# shellcheck source=/etc/os-release
. /etc/os-release
if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
  echo "ERROR: Ubuntu 24.04 LTS is required. Detected: ${PRETTY_NAME:-unknown}" >&2
  exit 1
fi

echo "==> AI Workstation v$SPEC_VERSION"
echo "==> OS: ${PRETTY_NAME}"
echo "==> Architecture: $(dpkg --print-architecture)"
echo "==> Started: $(date -Is)"

export DEBIAN_FRONTEND=noninteractive

echo "==> Updating base system"
apt-get update
apt-get -y upgrade

echo "==> Installing base packages"
# Prevent the XRDP package from briefly opening a public listener before its
# private binding is written below.
systemctl mask xrdp.service xrdp-sesman.service >/dev/null 2>&1 || true
apt-get install -y \
  ca-certificates curl wget gnupg lsb-release apt-transport-https \
  git jq unzip zip tar xz-utils build-essential \
  python3 python3-pip python3-venv pipx \
  ripgrep fd-find sqlite3 shellcheck zsh fzf \
  micro bat eza openssh-client openssh-server git-lfs unattended-upgrades \
  xfce4 xfce4-goodies xrdp xorgxrdp dbus-x11

# Ubuntu names these binaries differently.
ln -sf "$(command -v fdfind)" /usr/local/bin/fd
ln -sf "$(command -v batcat)" /usr/local/bin/bat

echo "==> Installing Docker Engine from Docker's Ubuntu repository"
for pkg in docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc; do
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    apt-get remove -y "$pkg"
  fi
done

# The Codex Universal image may already include Docker's legacy one-line APT
# source. Preserve it under a disabled filename before writing the authoritative
# deb822 source below, avoiding duplicate repository warnings.
if [[ -f /etc/apt/sources.list.d/docker.list ]] \
  && grep -q 'download.docker.com' /etc/apt/sources.list.d/docker.list; then
  mv -f /etc/apt/sources.list.d/docker.list \
    /etc/apt/sources.list.d/docker.list.ai-workstation-disabled
fi

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

echo "==> Installing Visual Studio Code"
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
  | gpg --batch --yes --dearmor -o /etc/apt/keyrings/packages.microsoft.gpg
chmod go+r /etc/apt/keyrings/packages.microsoft.gpg
cat > /etc/apt/sources.list.d/vscode.sources <<EOF
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/packages.microsoft.gpg
EOF
apt-get update
apt-get install -y code

echo "==> Installing graphical browser"
case "$(dpkg --print-architecture)" in
  amd64)
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
      | gpg --batch --yes --dearmor -o /etc/apt/keyrings/google-chrome.gpg
    chmod go+r /etc/apt/keyrings/google-chrome.gpg
    cat > /etc/apt/sources.list.d/google-chrome.sources <<'EOF'
Types: deb
URIs: https://dl.google.com/linux/chrome/deb/
Suites: stable
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/google-chrome.gpg
EOF
    apt-get update
    apt-get install -y google-chrome-stable
    ;;
  arm64)
    apt-get install -y chromium-browser
    ;;
  *)
    echo "ERROR: no supported graphical browser for $(dpkg --print-architecture)" >&2
    exit 1
    ;;
esac

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
if ! id "$AI_WORKSTATION_USER" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" --shell "$(command -v zsh)" "$AI_WORKSTATION_USER"
fi
usermod -aG sudo,docker "$AI_WORKSTATION_USER"
chsh -s "$(command -v zsh)" "$AI_WORKSTATION_USER"
DESKTOP_GROUP="$(id -gn "$AI_WORKSTATION_USER")"
DESKTOP_HOME="$(getent passwd "$AI_WORKSTATION_USER" | cut -d: -f6)"
chown root:"$DESKTOP_GROUP" /workspace /workspace/projects
chmod 0775 /workspace /workspace/projects
printf 'startxfce4\n' > "$DESKTOP_HOME/.xsession"
chown "$AI_WORKSTATION_USER:$DESKTOP_GROUP" "$DESKTOP_HOME/.xsession"
chmod 0644 "$DESKTOP_HOME/.xsession"

echo "==> Securing remote desktop until Tailscale is authorized"
sed -i '/^\[Globals\]/,/^\[/{s|^port=.*|port=tcp://127.0.0.1:3389|;}' /etc/xrdp/xrdp.ini
install -m 0755 "$(dirname "$0")/enable-rdp.sh" /usr/local/sbin/ai-workstation-enable-rdp
install -m 0755 "$(dirname "$0")/wait-rdp-address.sh" /usr/local/sbin/ai-workstation-wait-rdp-address
install -d -m 0755 /etc/systemd/system/xrdp.service.d
cat > /etc/systemd/system/xrdp.service.d/ai-workstation.conf <<'EOF'
[Unit]
Wants=tailscaled.service network-online.target
After=tailscaled.service network-online.target

[Service]
ExecStartPre=/usr/local/sbin/ai-workstation-wait-rdp-address
EOF
systemctl daemon-reload
systemctl unmask xrdp.service xrdp-sesman.service >/dev/null 2>&1 || true
systemctl enable --now xrdp

echo "==> Enabling automatic security updates"
dpkg-reconfigure -f noninteractive unattended-upgrades

echo "==> Installing verification command"
install -m 0755 "$(dirname "$0")/verify.sh" /usr/local/bin/verify-ai-workstation

echo "==> Running verification"
/usr/local/bin/verify-ai-workstation

echo "==> Finished: $(date -Is)"
echo "==> Full log: $LOG_FILE"
echo "==> Verification report: $REPORT_FILE"
