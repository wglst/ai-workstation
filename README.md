# AI Workstation v0.5

Portable, one-time boot provisioning for an Ubuntu engineering workstation.

## Operating model

The package is provider-agnostic. The substrate only needs to supply a fresh Ubuntu machine and an SSH public key for first access.

1. Copy this package to the fresh Ubuntu machine.
2. Run `stage-next-boot.sh` once as root.
3. Reboot.
4. On the next boot, systemd provisions and verifies the workstation automatically.
5. If verification succeeds, the one-shot service disables itself and schedules one final reboot.
6. The following boot is the finished workstation.

## Stage command

```bash
sudo ./stage-next-boot.sh
sudo reboot
```

## Logs and status

- `/var/log/ai-workstation/install.log`
- `/var/log/ai-workstation/report.txt`
- `/var/log/ai-workstation/first-boot.log`
- `/var/log/ai-workstation/final-verification.txt`
- `/var/lib/ai-workstation/provisioned` — success marker

Check status after provisioning:

```bash
cat /var/log/ai-workstation/report.txt
cat /var/log/ai-workstation/final-verification.txt
systemctl status ai-workstation-firstboot.service --no-pager
```

## Recovery behavior

If provisioning fails, the success marker is not created. The service remains enabled and will try again on the next reboot. Inspect the logs before retrying.

To intentionally re-run provisioning after a successful build:

```bash
sudo rm -f /var/lib/ai-workstation/provisioned
sudo systemctl enable ai-workstation-firstboot.service
sudo reboot
```

## Security rule

Do not bake private keys, API tokens, GitHub authentication, Codex authentication, Claude authentication, or Tailscale authentication into this package. SSH public keys are deployment inputs supplied by DigitalOcean, cloud-init, UTM, or another substrate.
