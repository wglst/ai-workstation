# AI Workstation v0.6

Deterministic, provider-agnostic provisioning for a disposable Ubuntu AI development desktop.

The machine is not the asset. This package is the asset: a blank Ubuntu machine plus this pinned source must produce the same verified workstation. It reproduces the declared functional state; upstream security and application patch versions intentionally advance unless a future release pins them.

## Reproduced state

- Docker Engine and Compose, Node.js 22, Python, uv, pipx, Git, GitHub CLI and Git LFS
- Codex CLI, Claude Code, shell and terminal utilities
- XFCE desktop, XRDP, Visual Studio Code and Chrome on amd64 (Chromium on arm64)
- Tailscale for private access
- A configurable desktop user with `sudo`, Docker access and a writable `/workspace/projects`
- Automatic security updates
- A deterministic PASS/FAIL report under `/var/log/ai-workstation`

## Deliberately private state

The package never contains passwords, SSH private keys, browser cookies or profiles, API tokens, GitHub/Codex/Claude logins, or a Tailscale device identity. Those are post-provision inputs or separately synchronized user data.

## Operating model

The substrate only needs a fresh Ubuntu 24.04 LTS machine and an SSH public key for first access.

1. Copy a pinned version of this package to the machine.
2. Stage it once as root.
3. Reboot. Systemd installs and verifies the workstation.
4. A successful build records its PASS state and schedules one final reboot.
5. Set the desktop user's password and authorize Tailscale.
6. Enable XRDP on the current Tailscale address. XRDP is never bound to a public or wildcard address.

## Stage and provision

The default desktop user is `harry`. Override it only when staging:

```bash
sudo AI_WORKSTATION_USER=harry ./stage-next-boot.sh
sudo reboot
```

After the second reboot, complete the private access steps:

```bash
sudo passwd harry
sudo tailscale up
sudo ai-workstation-enable-rdp
sudo verify-ai-workstation
```

Connect an RDP client to the Tailscale address reported by `ai-workstation-enable-rdp`, using the desktop username and the password you set. Tailscale authorization and the password are intentionally not automated.

## Pinned archive bootstrap

For cloud-init or another substrate adapter, point the bootstrap script at an immutable release or commit archive:

```bash
sudo AI_WORKSTATION_ARCHIVE_URL='https://github.com/wglst/ai-workstation/archive/<immutable-commit>.tar.gz' \
  AI_WORKSTATION_USER=harry \
  ./bootstrap/bootstrap.sh
sudo reboot
```

Do not use a moving branch URL for a reproducible build.

## Verification and evidence

```bash
cat /var/log/ai-workstation/report.txt
cat /var/log/ai-workstation/final-verification.txt
systemctl status ai-workstation-firstboot.service --no-pager
```

Evidence files:

- `/var/log/ai-workstation/install.log`
- `/var/log/ai-workstation/report.txt`
- `/var/log/ai-workstation/first-boot.log`
- `/var/log/ai-workstation/final-verification.txt`
- `/var/lib/ai-workstation/provisioned` - success marker

Before Tailscale authorization, verification reports XRDP as localhost-only. After `ai-workstation-enable-rdp`, it reports the private Tailscale binding.

## Recovery behavior

If provisioning fails, the success marker is not created. The service remains enabled and retries on the next reboot. Inspect the logs before retrying.

To intentionally re-run provisioning after a successful build:

```bash
sudo rm -f /var/lib/ai-workstation/provisioned
sudo systemctl enable ai-workstation-firstboot.service
sudo reboot
```

## Security boundary

Remote desktop starts bound to `127.0.0.1` and becomes remotely reachable only after Tailscale is authorized and `ai-workstation-enable-rdp` binds it to the machine's Tailscale IPv4 address. A cloud firewall is still recommended as defense in depth, but public XRDP access is not required.
