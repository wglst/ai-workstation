# AI Workstation v0.4

Canonical model:

Fresh Ubuntu -> tiny bootstrap -> versioned install.sh -> verify.sh -> PASS/FAIL report

## Design rules

- The operator's Mac is not part of the workstation architecture.
- No Terraform or Ansible is required on the operator machine.
- Provider-specific logic is limited to creating Ubuntu and injecting a bootstrap.
- `install.sh` is the canonical workstation build.
- `verify.sh` is the acceptance contract.
- Every install run is logged to `/var/log/ai-workstation/install.log`.
- Verification is written to `/var/log/ai-workstation/report.txt`.
- SSH keys are deployment inputs; they are never baked into the workstation spec.
- Secrets are never embedded in the repository or image.
- Release URLs should be pinned to a version tag or immutable commit.

## Files

- `install.sh` — installs and configures the workstation.
- `verify.sh` — validates required tools, services, paths, and versions.
- `bootstrap/bootstrap.sh` — generic bootstrap for any provider or local VM.
- `bootstrap/cloud-init.yaml` — cloud-init wrapper for providers/VMs supporting cloud-init.

## First deployment

1. Put this package in a private or public Git repository.
2. Create a version/tag, for example `v0.4`.
3. Replace the two `REPLACE_WITH_VERSIONED_RAW_*_URL` placeholders in the bootstrap.
4. Create a fresh Ubuntu VM/Droplet and inject the cloud-init file.
5. Let cloud-init complete.
6. SSH into the machine and run:

```bash
cat /var/log/ai-workstation/report.txt
```

For full diagnostics:

```bash
cat /var/log/ai-workstation/install.log
```

## Authentication

The package installs Codex CLI, Claude Code, GitHub CLI, and Tailscale, but intentionally does not store credentials.
Authenticate those services after provisioning or inject credentials through a separate secret-management mechanism.

## Golden image

Only create a golden image after `verify-ai-workstation` returns `RESULT: PASS`.
The script remains the source of truth; the image is a restore/acceleration artifact.
