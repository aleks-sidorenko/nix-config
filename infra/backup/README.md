# Backup storage

The R2 bucket offsite backups go to (`lib/defaults.backup`), managed with
terranix/OpenTofu like `infra/dns`. Only the bucket lives here; the S3
credential restic uses is created by hand and stored in SOPS.

Bootstrap order and restore: see `docs/homelab.md` → *Backup*.

| Recipe | |
| --- | --- |
| `just backup-show` | Rendered terraform JSON |
| `just backup-validate` | Syntax and provider schema |
| `just backup-plan` / `backup-apply` | Plan / apply |
| `just backup-secrets-edit` | Edit `secrets.yaml` (`cloudflare-api-token`: R2 Edit only; `state-passphrase`) |
