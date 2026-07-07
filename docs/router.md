# Router Management

The MikroTik RouterOS configuration is managed declaratively. The RouterOS module abstraction lives in the standalone [nix-routeros](https://github.com/aleks-sidorenko/nix-routeros) flake (a `nix run .#router` entrypoint built on [terranix](https://github.com/terranix/terranix) and [OpenTofu](https://opentofu.org/)); this repo only holds the host-specific configuration and state.

## Architecture

```
infra/router/default.nix (host config)
    │
    ▼
nix-routeros flake ── mkRouterDerivation
    │
    ▼
terranix ── generates ──▶ Terraform JSON
    │
    ▼
OpenTofu ── applies via REST API ──▶ MikroTik RouterOS
```

`infra/router/default.nix` calls `inputs.nix-routeros.lib.mkRouterDerivation`, passing the declarative router config (bridge ports, DNS, WiFi/CAPsMAN, LTE, firewall, hosts) plus SOPS secrets and the state directory. The RouterOS resource schema and terranix/OpenTofu wiring are provided by the flake.

## Configuration Structure

```
infra/router/
├── default.nix           # Router config passed to mkRouterDerivation + SSH backup script
├── hosts.nix             # Static host/device definitions (IPs, MACs)
├── imports.nix           # RouterOS resource ID mappings (for `terraform import` of existing config)
├── encryption.tf         # OpenTofu state encryption configuration
├── secrets.yaml          # SOPS-encrypted secrets
├── terraform.tfstate     # OpenTofu state (natively encrypted, committed)
├── README.md             # Operational notes (banned address list, DHCP leases)
├── config.tf.json        # Generated Terraform JSON (build artifact, untracked)
└── .terraform/           # OpenTofu providers (auto-managed, untracked)
```

## Prerequisites

1. **Enable the old API on the router:**
   ```
   /ip service set api disabled=no address=10.0.0.0/24
   ```

2. **Configure SOPS secrets** (`infra/router/secrets.yaml`):
   - `router-api-password` - RouterOS API password
   - `wifi-password` - WiFi network password
   - `state-passphrase` - OpenTofu state encryption passphrase

## Commands

| Command | Description |
|---------|-------------|
| `just router-show` | Display generated Terraform JSON |
| `just router-plan` | Preview changes (dry-run) |
| `just router-apply` | Apply changes to router |
| `just router-backup` | Create SSH backup of router config |
| `just router-secrets` | Edit router SOPS secrets |
| `just router-destroy` | Destroy Terraform state (dangerous!) |
| `just router-help` | Show help with examples |

Or via Nix directly:

```bash
nix run .#router          # Show generated JSON
nix run .#router.plan     # Plan
nix run .#router.apply    # Apply
nix run .#router.destroy  # Destroy
nix run .#router.backup   # Backup
```

## Typical Workflow

```bash
# 1. Make changes to modules in infra/router/modules/

# 2. Preview changes
just router-plan

# 3. Review the plan output

# 4. Apply changes
just router-apply

# 5. Commit updated state file
git add infra/router/terraform.tfstate
git commit -m "router: applied configuration changes"
```

## Deploy via justfile

The router can also be deployed using the standard deploy command:

```bash
just deploy router    # Runs: nix run .#router.apply
```

## Secrets

Secrets are managed via SOPS and automatically injected as environment variables:

| Environment Variable | SOPS Key | Purpose |
|---------------------|----------|---------|
| `TF_VAR_routeros_password` | `router-api-password` | RouterOS API authentication |
| `TF_VAR_wifi_password` | `wifi-password` | WiFi network password |
| `TF_VAR_state_passphrase` | `state-passphrase` | OpenTofu state encryption |

Edit secrets:
```bash
just router-secrets
```

## State Management

OpenTofu state is stored locally at `infra/router/terraform.tfstate` and encrypted natively by OpenTofu using PBKDF2 + AES-GCM with the `state-passphrase` from SOPS secrets. The encrypted state file is committed to git.

## Backup

Create a backup of the running router configuration:

```bash
just router-backup                    # Save to ~/.config/mikrotik/
just router-backup --output ~/backups  # Save to custom directory
```

This SSHs into the router, creates a backup file (`nix-<timestamp>`), and downloads it locally.

## Managed Devices

Static DHCP leases and DNS entries are defined in `infra/router/hosts.nix`. See [docs/homelab.md](homelab.md) for the network layout table.

Day-to-day operational notes — inspecting DHCP leases and managing the `banned` address list (hosts blocked from WAN traffic) — live in [`infra/router/README.md`](../infra/router/README.md).
