# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal NixOS/nix-darwin configuration using **snowfall-lib** for modular organization. It manages multiple systems (desktop, server, macOS workbook) with declarative configurations for NixOS, home-manager, and nix-darwin.

## Common Commands

### Build & Deploy

```bash
# Local builds (NixOS)
nh os switch              # Build system configuration (uses hostname)
nh home switch            # Build user configuration (uses hostname + username)
sudo nixos-rebuild switch --flake .  # Alternative local build

# Remote deployment via deploy-rs
just deploy <hostname>                           # Deploy with local build
just deploy <hostname> --remote-build            # Build on target
just deploy <hostname> --dry-run                 # Preview changes

# Examples
just deploy server --remote-build
just deploy vm --remote-build --verbose
```

### Testing & Validation

```bash
# Code quality
just lint                  # Lint with statix + deadnix (read-only)
just lint-fix              # Auto-fix lint issues (statix + deadnix)
just format [path]         # Format nix files with nixfmt-tree (writes)
just format-check          # Verify formatting (read-only)
just check                 # CI-safe umbrella: format-check + lint

# Build validation
just build                 # Build configuration without switching (read-only)
just switch                # Build and switch to new generation locally
just flake-check           # nix flake check
nix flake check            # Same as above

# Bootstrap validation
just bootstrap-validate    # Shellcheck on bootstrap scripts
```

### Bootstrap & Installation

```bash
# Complete bootstrap (secrets + deploy)
just bootstrap <hostname> [username] [disk_password] [extra_opts...]

# Two-step bootstrap (for advanced control)
just bootstrap-secrets <hostname> [disk_password]  # Step 1: Generate secrets
export KEYSDIR=/tmp/tmp.XXX                        # Use output from step 1
just bootstrap-deploy <hostname> [username] [extra_opts...]  # Step 2: Deploy

# Disk formatting with disko
just bootstrap-disk <hostname>            # Preview (dry-run)
just bootstrap-disk <hostname> --apply    # Apply and format disks

# Raspberry Pi firmware
just bootstrap-rpi-firmware <hostname> [username] [target_dir] [version]
```

### Information & Discovery

```bash
just info                  # Show system info
just list-configs          # List all configurations (nixos + darwin + home)
just list-configs nixos    # List a single type: nixos | darwin | home
just bootstrap-targets     # List hosts available for bootstrap
just outputs               # Show flake outputs
```

### Secrets Management

```bash
just secrets-list          # List SOPS secrets
just secrets-edit nixos    # Edit NixOS secrets
just secrets-edit home     # Edit home-manager secrets

# Manual SOPS operations
sops --decrypt modules/nixos/secrets.yaml
sops updatekeys modules/nixos/secrets.yaml
```

### Maintenance

```bash
just update                # Update flake inputs
just cleanup               # Garbage collect and remove old generations
just disk-usage            # Show nix store disk usage
```

## Architecture

### Snowfall-lib Structure

This config uses **snowfall-lib** conventions for automatic module discovery:

- **`systems/<arch>/<hostname>/`**: System configurations (NixOS/darwin)
- **`systems/<arch>-<format>/<hostname>/`**: Special format systems (e.g., `x86_64-install-iso/minimal/` produces `install-isoConfigurations` via nixos-generators)
- **`homes/<arch>/<user>@<hostname>/`**: Home-manager configurations
- **`modules/nixos/`**: NixOS modules
- **`modules/home/`**: Home-manager modules
- **`modules/darwin/`**: nix-darwin modules
- **`packages/`**: Custom packages
- **`overlays/`**: Nixpkgs overlays
- **`lib/`**: Custom library functions
- **`infra/`**: Infrastructure-as-code (terranix/OpenTofu, not auto-discovered by snowfall-lib)

### Custom Namespace

All modules use the `${namespace}` pattern (defaults to `nix-config`) to avoid conflicts with upstream options. Access via `config.nix-config.*`.

Example:
```nix
config.nix-config.user.name
config.nix-config.roles.desktop.enable
```

### Key Library Functions

Located in `lib/`:

**`lib/module/default.nix`**: Module option helpers
- `mkOpt`, `mkBoolOpt`, `mkPackageOpt`, `mkStringOpt` - Create typed options
- `enabled` / `disabled` - Shorthand for `{ enable = true/false; }`

**`lib/context/default.nix`**: Context detection
- `isNixOS config` - Check if in NixOS context
- `isHomeManager config` - Check if in home-manager context
- `getContext config` - Returns "nixos", "home", or "unknown"
- `userName config` - Get username across contexts
- `homeConfig config` - Access home-manager config from either context

**`lib/deploy/default.nix`**: deploy-rs configuration
**`lib/fs/default.nix`**: Filesystem utilities
**`lib/net/default.nix`**: Network utilities

### Role-Based Configuration

Both NixOS and home-manager use a **role system** for composable configurations:

**NixOS roles** (`modules/nixos/roles/`):
- `common` - Base system config (SSH, SOPS, networking, locale, impermanence)
- `desktop` - Desktop environment base
- `server` - Server base configuration
- `home-server`, `media-server`, `gaming-server`, `smart-home`, etc.

**Home-manager roles** (`modules/home/roles/`):
- `common` - Base user config
- `desktop`, `development`, `gaming`, `media`, `mobile`, `social`, `work`

Enable roles in system configs:
```nix
nix-config.roles.desktop.enable = true;
```

### User Management

User configuration is centralized in `modules/nixos/user/`:
- Set `nix-config.user.name` to define the primary user
- Integrates with SOPS for password management via `user-${username}-password` secret
- Automatically configures home-manager for the user
- Default shell set via `nix-config.cli.shells.default.package`

### Secrets with SOPS

- **NixOS secrets**: `modules/nixos/secrets.yaml`
- **Home-manager secrets**: `modules/home/secrets.yaml`
- Age keys configuration: `.sops.yaml` at repo root
- Bootstrap scripts handle SSH host keys and age key generation
- Use `sops updatekeys` after adding new hosts to `.sops.yaml`

### Disk Management

**Disko** (`modules/nixos/disks/`):
- Declarative disk layouts per-host in `systems/<arch>/<hostname>/disks.nix`
- BTRFS with encryption, subvolumes, and impermanence
- Blank snapshot approach for root filesystem
- Boot configuration in `modules/nixos/disks/boot/`
- Impermanence in `modules/nixos/disks/impermanence/`

**Impermanence**: Opt-in persistence with `/persist` directory. Root filesystem is wiped on boot.

### Desktop Environments

Supports multiple desktop environments:

**Hyprland** (`modules/nixos/desktops/hyprland/`, `modules/home/desktops/hyprland/`):
- NixOS module for system-level Hyprland config
- Home-manager module for user-level config
- Addons: hypridle, hyprlock, hyprpaper, pyprland
- Window rules in `modules/home/desktops/hyprland/windowrules.nix`

**GNOME** (`modules/home/desktops/gnome/`)

**Waybar, swaync, wlogout, kanshi**: Available as addons in `modules/home/desktops/addons/`

**Styling**: Managed by **stylix** (`modules/nixos/styles/stylix/`)

### Custom Packages

**`packages/nvim/`**: Custom Neovim configuration using **nixvim**
- Modular plugin organization in `plugins/`
- Per-language configuration toggles (haskell, rust, python, go, typescript, scala, java)
- AI assistant options (copilot, claude-code)
- Structured as: `settings.nix`, `keymaps.nix`, `auto_cmds.nix`, `file_types.nix`

**`packages/install/`**: Custom NixOS installer ISO configuration

**`packages/wallpapers/`**: Wallpaper package

### Hardware Configurations

- Per-host hardware configs in `systems/<arch>/<hostname>/hardware.nix`
- Hardware modules in `modules/nixos/hardware/`: audio, bluetooth, video (nvidia/nouveau), zsa keyboards, raspberry-pi-4
- Uses nixos-hardware flake for common hardware profiles

### Multi-Architecture Support

- **x86_64-linux**: Desktop, VM
- **x86_64-install-iso**: Minimal installer ISO (built via `nix build .#install-isoConfigurations.minimal`)
- **aarch64-linux**: Raspberry Pi 4 server
- **aarch64-darwin**: macOS workbook

Darwin-specific modules in `modules/darwin/` with separate role system.

### Homelab Services

Services in `modules/nixos/services/`:
- `k3s/` - Kubernetes
- `smart-home/` - Home Assistant, Mosquitto MQTT
- `media/jellyfin/` - Media server
- `backup/` - Backup services
- `virtualisation/podman/` - Container runtime
- `networking/tailscale/` - VPN mesh

### Infrastructure-as-Code

IaC configurations in `infra/`:
- `router/` - MikroTik RouterOS managed via terranix/OpenTofu
  - `default.nix` - terranix derivation and backup script
  - `modules/` - terraform modules (bridge, capsman, dhcp, dns, firewall, interfaces, etc.)
  - `secrets.yaml` - SOPS-encrypted secrets (router API password, WiFi, state passphrase)
  - `terraform.tfstate` - encrypted OpenTofu state
  - Managed via `just router-*` commands

## Development Workflow

1. **Make changes** to modules or system configs
2. **Format code**: `just format`
3. **Validate**: `just check`
4. **Test build**: `just build` (local) or `nix flake check`
5. **Deploy**: `just deploy <hostname>` or `nh os switch` (local)
6. **Commit**: Standard git workflow

## Important Files

- `flake.nix` - Flake inputs and outputs, snowfall-lib integration
- `justfile` - All automation commands
- `.sops.yaml` - SOPS age keys configuration
- `scripts/common.sh` - Shared script utilities
- `scripts/bootstrap/bootstrap-secrets.sh` - Secret and SSH key preparation
- `scripts/bootstrap/bootstrap-deploy.sh` - nixos-anywhere deployment wrapper
- `scripts/bootstrap/bootstrap-rpi-firmware.sh` - Raspberry Pi firmware installation

## Bootstrap Prerequisites

- SSH access to target with passwordless sudo
- `pass` configured with file storage
- Target host configuration exists in flake
- For encryption: LUKS password provided to bootstrap

## Testing Configurations

Use the VM configuration for testing:
```bash
# In systems/x86_64-linux/vm/
just deploy vm --hostname vm --skip-checks
```

VM is provisioned via Vagrant with SSH keys from GitHub.
