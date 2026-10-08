# Object storage

The Cloudflare R2 buckets this account uses, managed with terranix/OpenTofu
like `infra/dns`. Today that is `backups`, where offsite backups go
(`lib/defaults.backup`). Only buckets live here; the S3 credential restic uses
is created by hand and stored in SOPS.

Bootstrap order and restore: see `docs/homelab.md` → *Backup*.

| Recipe | |
| --- | --- |
| `just storage-show` | Rendered terraform JSON |
| `just storage-validate` | Syntax and provider schema |
| `just storage-plan` / `storage-apply` | Plan / apply |
| `just storage-secrets-edit` | Edit `secrets.yaml` (`state-passphrase` only; the Cloudflare token is in `infra/secrets.yaml`, `just infra-secrets-edit`) |
