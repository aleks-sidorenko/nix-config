# Documentation Restructuring Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restructure repository documentation with a middle-ground README (~200 lines) containing condensed usage inline, plus docs/ files for deep-dives on architecture, bootstrap, homelab, router, and references.

**Architecture:** README.md becomes a self-contained landing page with features, configs table, condensed usage (deploy, secrets, maintenance), and a documentation index linking to docs/. Deep-dive topics (bootstrap, architecture, homelab services, router management) live in dedicated docs/ files. CLAUDE.md stays independent.

**Tech Stack:** Markdown documentation only. No code changes.

---

### Task 1: Create `docs/references.md`

**Files:**
- Create: `docs/references.md`

**Step 1: Write the file**

```markdown
# References

## Credits

- <a href="https://www.flaticon.com/free-icons/dot" title="dot icons">Dot icons created by Roundicons - Flaticon</a>

### Wallpapers

- [Catppuccin Discord - Galaxy](https://discord.com/channels/907385605422448742/1199293891392852009)
- [Old Catppuccin wallpapers by Gingeh](https://github.com/Gingeh/wallpapers)
- [Catppuccin Discord - Catppuccino](https://discord.com/channels/907385605422448742/1130546126374838342)

## Inspired By

- [hmajid2301/nixicle](https://github.com/hmajid2301/nixicle) - Snowfall-based config
- [jakehamilton/config](https://github.com/jakehamilton/config/tree/main) - Snowfall-based, mature config with extensive modules
- [8bitbuddhist/nix-configuration](https://github.com/8bitbuddhist/nix-configuration) - Snowfall-based config
- [Misterio77/nix-config](https://github.com/Misterio77/nix-config)
- [EmergentMind/nix-config](https://github.com/EmergentMind/nix-config)
- [dc-tec/nixvim](https://github.com/dc-tec/nixvim) - Nixvim configuration
- [khaneliman/khanelivim](https://github.com/khaneliman/khanelivim/tree/main) - Dev-oriented nixvim config
- [Stunkymonkey/nixos](https://github.com/Stunkymonkey/nixos) - Raspberry Pi 4 NixOS
- [azuwis/nix-config](https://github.com/azuwis/nix-config/tree/master/nixos/hass) - Home Assistant on NixOS
- [nathan-gs/nix-conf](https://github.com/nathan-gs/nix-conf/tree/main/smarthome) - Smart home on NixOS

## NixOS Resources

- [Snowfall Lib - Modules Guide](https://snowfall.org/guides/lib/modules/)
- [NixOS Wiki - NixOS Modules](https://nixos.wiki/wiki/NixOS_modules)
- [nix.dev - Module System Deep Dive](https://nix.dev/tutorials/module-system/deep-dive)
- [NixOS Asia - Nix Modules](https://nixos.asia/en/nix-modules)

## Key Upstream Projects

| Project | Description |
|---------|-------------|
| [snowfall-lib](https://github.com/snowfallorg/lib) | Modular flake organization framework |
| [home-manager](https://github.com/nix-community/home-manager) | User environment management |
| [nix-darwin](https://github.com/nix-darwin/nix-darwin) | macOS system configuration |
| [deploy-rs](https://github.com/serokell/deploy-rs) | Remote NixOS deployment |
| [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) | Remote NixOS installation |
| [disko](https://github.com/nix-community/disko) | Declarative disk partitioning |
| [sops-nix](https://github.com/Mic92/sops-nix) | Secrets management with SOPS |
| [impermanence](https://github.com/nix-community/impermanence) | Opt-in state persistence |
| [stylix](https://github.com/nix-community/stylix) | System-wide theming |
| [nixvim](https://github.com/nix-community/nixvim) | Neovim configuration in Nix |
| [terranix](https://github.com/terranix/terranix) | Terraform/OpenTofu in Nix |
| [nixos-hardware](https://github.com/NixOS/nixos-hardware) | Hardware-specific NixOS modules |
```

**Step 2: Verify file was created**

Run: `head -5 docs/references.md`
Expected: First 5 lines of the file visible

**Step 3: Commit**

```bash
git add docs/references.md
git commit -m "docs: add references (moved from README appendix)"
```

---

### Task 2: Create `docs/architecture.md`

**Files:**
- Create: `docs/architecture.md`

**Step 1: Write the file**

```markdown
# Architecture

## Snowfall-lib Structure

This configuration uses [snowfall-lib](https://github.com/snowfallorg/lib) conventions for automatic module discovery based on directory structure:

```
.
├── flake.nix                       # Flake definition and inputs
├── systems/                        # System configurations (auto-discovered)
│   ├── x86_64-linux/
│   │   ├── desktop/                # Primary desktop workstation
│   │   └── vm/                     # Vagrant test VM
│   ├── x86_64-install-iso/
│   │   └── minimal/                # Custom NixOS installer ISO
│   ├── aarch64-linux/
│   │   └── server/                 # Raspberry Pi 4 home server
│   └── aarch64-darwin/
│       └── workbook/               # macOS work laptop
├── homes/                          # Home-manager configurations (auto-discovered)
│   ├── x86_64-linux/
│   │   ├── alexander@desktop/
│   │   └── alexander@vm/
│   └── aarch64-darwin/
│       └── oleksandrsy@workbook/
├── modules/                        # Shared modules
│   ├── nixos/                      # NixOS system modules
│   ├── home/                       # Home-manager user modules
│   └── darwin/                     # nix-darwin macOS modules
├── packages/                       # Custom packages (auto-discovered)
│   ├── nvim/                       # Neovim config via nixvim
│   ├── install/                    # Installer ISO
│   └── wallpapers/                 # Wallpaper package
├── overlays/                       # Nixpkgs overlays (auto-discovered)
├── lib/                            # Custom library functions (auto-discovered)
├── infra/                          # Infrastructure-as-code (NOT auto-discovered)
│   └── router/                     # MikroTik router via terranix/OpenTofu
└── scripts/                        # Bootstrap and utility scripts
    ├── common.sh
    └── bootstrap/
```

## Custom Namespace

All modules use the `nix-config` namespace to avoid conflicts with upstream NixOS/home-manager options:

```nix
# Defining options (in modules)
options.nix-config.services.backup.restic.enable = mkBoolOpt false "Enable restic backup";

# Using options (in system configs)
config.nix-config.roles.desktop.enable = true;
config.nix-config.user.name = "alexander";
```

The namespace is set in `flake.nix` via `snowfall.namespace = "nix-config"`.

## Role-Based Configuration

Roles are composable configuration bundles. Enabling a role pulls in all its sub-roles and module configurations.

### NixOS Roles (`modules/nixos/roles/`)

| Role | Composes | Configures |
|------|----------|------------|
| **common** | - | SSH, SOPS, Nix, locale, networking, fish shell, boot, impermanence, user |
| **desktop** | common, gaming, backup | nh, nix-ld, stylix, GNOME, VirtualBox, Podman, hibernation |
| **server** | common | nginx, NFS utils, NetworkManager hardening, TCP BBR, systemd watchdog |
| **home-server** | common, server, media-server, smart-home, gaming-server, backup-server, backup | _(aggregates all server roles)_ |
| **media-server** | - | qBittorrent, Jellyfin, Radarr, Sonarr, Prowlarr, MiniDLNA |
| **smart-home** | - | Home Assistant (climate, heatpump, inverter, telegram, weather, plugs), Mosquitto, Zigbee2MQTT |
| **gaming-server** | - | Minecraft server |
| **backup-server** | - | Restic REST server |
| **backup** | - | Restic backup client |
| **gaming** | - | Xbox controller support, 32-bit graphics, Mesa |

### Home-Manager Roles (`modules/home/roles/`)

| Role | Composes | Configures |
|------|----------|------------|
| **common** | - | Nix, locale, GPG, SSH, SOPS, pass, fish, ghostty, neovim, archivers, modern-unix, network-tools, stylix |
| **desktop** | common, development, media, mobile, gaming, communication, router | Teamviewer, GNOME, Chrome, Firefox, Wayland tools |
| **work** | common, development, router | Chrome, Teamviewer (macOS-oriented) |
| **development** | - | VS Code, Cursor, IDEA, languages (haskell, rust, python, go, typescript, scala, java), Bazel, MySQL, Testcontainers, AI (copilot, claude-code), Podman, k8s |
| **media** | - | VLC, Shotwell |
| **mobile** | - | MTP tools (Android integration) |
| **gaming** | - | Minecraft |
| **communication** | - | Telegram, Viber |
| **router** | - | Winbox (MikroTik management) |

### Darwin Roles (`modules/darwin/roles/`)

| Role | Composes | Configures |
|------|----------|------------|
| **common** | - | SOPS, Nix, macOS defaults, networking, Homebrew, fish, nh, user |
| **work** | common | Viber, Telegram, Zoom, Slack, Chromium, Rancher |

## Library Functions

### `lib/module` - Option Helpers

| Function | Description |
|----------|-------------|
| `mkOpt type default description` | Create a typed module option |
| `mkBoolOpt default description` | Boolean option shorthand |
| `mkPackageOpt package description` | Package option shorthand |
| `mkStringOpt default description` | String option shorthand |
| `enabled` / `disabled` | Shorthand for `{ enable = true/false; }` |

Primed variants (`mkOpt'`, `mkBoolOpt'`, etc.) omit the description parameter.

### `lib/context` - Context Detection

| Function | Description |
|----------|-------------|
| `isNixOS config` | Returns true if evaluating in NixOS context |
| `isHomeManager config` | Returns true if evaluating in home-manager context |
| `getContext config` | Returns `"nixos"`, `"home"`, or `"unknown"` |
| `userName config` | Get username regardless of context |
| `homeDir config` | Get home directory regardless of context |
| `homeConfig config` | Access home-manager config from either context |

### `lib/deploy` - Deployment Configuration

| Function | Description |
|----------|-------------|
| `mkDeploy { self, overrides? }` | Generate deploy-rs node configuration from all nixosConfigurations |

Automatically extracts hostname, user, and sudo method (doas if configured) from each system config.

### `lib/defaults` - Global Defaults

Data structure (not functions) providing shared defaults:
- `user`: `"alexander"`
- `locale`: locales, keyboard layouts, timezone (`Europe/Kyiv`)
- `persistence.root`: `"/persist"`
- `network`: subnet (`10.0.0.0/24`), gateway, DHCP range, host IPs, domains (local, public), DNS upstream, WiFi SSID, service ports

### `lib/net` - Network Utilities

| Function | Description |
|----------|-------------|
| `hosts.local name` | Generate local hostname (`name.local`) |
| `hosts.public name` | Generate public hostname (`name.sidorenko.me`) |
| `networkAddress cidr` | Derive network address from CIDR |
| `prefixLength cidr` | Extract prefix length from CIDR |

### `lib/terraform` - Terranix Helpers

| Function | Description |
|----------|-------------|
| `mkTerranixDerivation { pkgs, system, name, modules, stateDir?, secretsFile?, secrets? }` | Create terranix derivation with OpenTofu and SOPS integration |

Generates `show`, `plan`, `apply`, `destroy` scripts. Auto-discovers modules from `terraformModulesPath` if provided.

## Multi-Architecture Support

| Architecture | Systems | Description |
|-------------|---------|-------------|
| `x86_64-linux` | desktop, vm | Desktop workstation, test VM |
| `aarch64-linux` | server | Raspberry Pi 4 home server |
| `aarch64-darwin` | workbook | macOS Apple Silicon laptop |
| `x86_64-install-iso` | minimal | Custom NixOS installer image |

## Key Flake Inputs

| Input | Channel/Version | Purpose |
|-------|----------------|---------|
| nixpkgs | nixos-25.11 | Stable package set |
| nixpkgs-unstable | nixos-unstable | Bleeding-edge packages (available as `pkgs.unstable`) |
| home-manager | release-25.11 | User environment management |
| snowfall-lib | latest | Modular flake organization |
| darwin | nix-darwin-25.11 | macOS system configuration |
| deploy-rs | latest | Remote NixOS deployment |
| disko | latest | Declarative disk partitioning |
| sops-nix | latest | Secrets management |
| impermanence | latest | Opt-in state persistence |
| nixos-anywhere | latest | Remote NixOS installation |
| stylix | release-25.11 | System-wide theming |
| nixvim | nixos-25.11 | Neovim in Nix |
| terranix | latest | Terraform/OpenTofu in Nix |
| Hyprland ecosystem | latest | hypr-contrib, hyprcursor, pyprland, hyprpanel |
| nix-homebrew | latest | Homebrew integration for macOS |
| catppuccin | latest | Catppuccin color scheme |
```

**Step 2: Verify file was created**

Run: `wc -l docs/architecture.md`
Expected: ~180-200 lines

**Step 3: Commit**

```bash
git add docs/architecture.md
git commit -m "docs: add architecture guide"
```

---

### Task 3: Create `docs/bootstrap.md`

**Files:**
- Create: `docs/bootstrap.md`
- Delete (later): `docs/howto.md`

**Step 1: Write the file**

```markdown
# Bootstrap & Installation

This guide covers installing NixOS on a new host using [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) and the bootstrap scripts in this repository.

## Prerequisites

- SSH access to target host with **passwordless sudo**
- [`pass`](https://www.passwordstore.org/) configured with file storage (for SSH key backup)
- Target host configuration exists in flake (`systems/<arch>/<hostname>/`)
- For disk encryption: a LUKS password
- Required tools on your local machine: `ssh-keygen`, `pass`, `nix`, `mktemp`

Verify SSH connectivity:
```bash
ssh -o ConnectTimeout=10 -o BatchMode=yes <username>@<hostname> "sudo -n true"
```

## Quick Start

### Complete Bootstrap (Recommended)

```bash
just bootstrap <hostname> [username] [disk_password] [extra_opts...]
```

Examples:
```bash
just bootstrap myserver                                    # Current user, no encryption
just bootstrap myserver alexander                          # Specific user
just bootstrap myserver alexander MyPassword123            # With disk encryption
just bootstrap myserver alexander MyPassword123 --build-on-remote  # Build on target
```

### Two-Step Bootstrap (Advanced)

For more control, split secrets generation and deployment:

```bash
# Step 1: Generate SSH keys and age keys
just bootstrap-secrets <hostname> [disk_password]

# Step 2: Export the keys directory path from step 1 output
export KEYSDIR=/tmp/tmp.XXXXXXXX

# Step 3: Deploy
just bootstrap-deploy <hostname> [username] [keysdir] [extra_opts...]
```

## What Bootstrap Does

1. **Checks prerequisites** - verifies SSH connectivity and required tools
2. **Generates SSH host keys** (Ed25519) - or retrieves existing keys from `pass` at `Infra/Host/<hostname>/ssh`
3. **Converts SSH public key to age format** using `ssh-to-age`
4. **Stores keys in `pass`** and pushes to git (for new keys)
5. **Prompts to update `.sops.yaml`** - add the new host's age key, then run `sops updatekeys`
6. **Runs nixos-anywhere** - deploys NixOS to the target with the prepared keys and optional disk encryption

The keys are placed in a temporary directory structure:
```
$KEYSDIR/extra/persist/etc/ssh/
├── ssh_host_ed25519_key
└── ssh_host_ed25519_key.pub
```

## Adding a New Host to SOPS

After bootstrap generates the age key for a new host:

1. Add the age key to `.sops.yaml`:
   ```yaml
   keys:
     - &hosts:
       - &myhost age1xxxx...xxxx   # Add this line
   ```

2. Add the host to the relevant creation rules:
   ```yaml
   creation_rules:
     - path_regex: modules/nixos/secrets.ya?ml$
       key_groups:
         - pgp:
             - *alexander
           age:
             - *myhost              # Add this line
   ```

3. Re-encrypt secrets with the new key:
   ```bash
   sops updatekeys modules/nixos/secrets.yaml
   sops updatekeys modules/home/secrets.yaml
   ```

## Adding a User Password to SOPS

```bash
# Generate password hash
nix-shell -p mkpasswd --run 'mkpasswd -m SHA-512'

# Edit secrets and add as user-<username>-password
just secrets-edit nixos
```

## Disk Formatting with Disko

Each system defines its disk layout in `systems/<arch>/<hostname>/disks.nix`. Use disko to format disks:

```bash
# Preview changes (dry-run)
just bootstrap-disk <hostname>

# Apply and format disks (DESTROYS ALL DATA)
just bootstrap-disk <hostname> --apply

# Then deploy to apply mount configuration
just deploy <hostname>
```

### Manual Formatting (Single Data Disk)

For adding a data disk without touching the system disk:

```bash
# Format with btrfs
sudo mkfs.btrfs -f -L <disk-label> /dev/disk/by-id/<disk-id>

# Mount and create subvolumes
sudo mount /dev/disk/by-id/<disk-id> /mnt
sudo btrfs subvolume create /mnt/@<subvol>
sudo umount /mnt

# Rebuild to apply mount configuration
sudo nixos-rebuild switch --flake .#<hostname>
```

## Raspberry Pi 4

### Prerequisites

1. [Prepare the RPi4 bootloader](https://github.com/fredrikaverpil/dotfiles/blob/main/nix/hosts/rpi5-homelab/README.md#prepare-bootloader-on-raspberry-pi-5): update bootloader and change boot order
2. Follow the [standard bootstrap process](#quick-start)

### Post-Install: Firmware

```bash
just bootstrap-rpi-firmware <hostname> [username] [target_dir] [version]
```

Examples:
```bash
just bootstrap-rpi-firmware myrpi                          # Defaults: current user, /mnt/boot, v1.42
just bootstrap-rpi-firmware myrpi pi /boot v1.50           # Custom settings
just bootstrap-rpi-firmware 192.168.1.100 root             # By IP
```

This downloads [RPi4 UEFI firmware](https://github.com/pftf/RPi4) and extracts it to the target directory.

### RPi4 Reference Links

- [kotatsuyaki/rpi4-usb-uefi-nixos-config](https://codeberg.org/kotatsuyaki/rpi4-usb-uefi-nixos-config)
- [pftf/RPi4](https://github.com/pftf/RPi4)
- [Stunkymonkey/nixos](https://github.com/Stunkymonkey/nixos/tree/master/machines/serverle)
- [fredrikaverpil/dotfiles](https://github.com/fredrikaverpil/dotfiles/blob/main/nix/hosts/rpi5-homelab/README.md)
- [NixOS on RPi4 with UEFI and ZFS](https://carlosvaz.com/posts/nixos-on-raspberry-pi-4-with-uefi-and-zfs/)

## VM (Testing)

The VM configuration is provisioned via Vagrant with SSH keys from GitHub:

```bash
vagrant up
vagrant ssh-config >> .ssh.config
```

Then bootstrap as normal:
```bash
just bootstrap vm
```

## Post-Installation: FIDO2 Setup

After a successful installation with LUKS encryption, you can optionally set up a FIDO2 hardware token for automatic unlocking:

```bash
ssh <username>@<hostname>
systemd-cryptenroll --fido2-device=auto /dev/disk/by-label/<device_name>
```

The system is pre-configured with `fido2-device=auto` in the LUKS settings.

## Bootstrap Command Reference

| Command | Description |
|---------|-------------|
| `just bootstrap <host> [user] [disk_pw] [opts]` | Complete bootstrap (secrets + deploy) |
| `just bootstrap-secrets <host> [disk_pw]` | Generate SSH/age keys only |
| `just bootstrap-deploy <host> [user] [keysdir] [opts]` | Deploy using existing keys |
| `just bootstrap-disk <host>` | Preview disk formatting (dry-run) |
| `just bootstrap-disk <host> --apply` | Format disks with disko |
| `just bootstrap-rpi-firmware <host> [user] [dir] [ver]` | Install RPi4 firmware |
| `just bootstrap-targets` | List available bootstrap targets |
| `just bootstrap-validate` | Shellcheck bootstrap scripts |
| `just bootstrap-help` | Show detailed bootstrap help |

### nixos-anywhere Options

Common options passed via `extra_opts`:

| Option | Description |
|--------|-------------|
| `--build-on-remote` | Build the system on the target host |
| `--phases <phases>` | Run specific phases: `kexec`, `disko`, `install`, `reboot` |
| `--debug` | Enable debug output |
| `--no-reboot` | Don't reboot after installation |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `KEYSDIR` | Keys directory (set by bootstrap-secrets, used by bootstrap-deploy) |
| `AUTO_APPROVE` | Skip interactive SOPS update confirmation |
```

**Step 2: Verify file was created**

Run: `wc -l docs/bootstrap.md`
Expected: ~180-200 lines

**Step 3: Commit**

```bash
git add docs/bootstrap.md
git commit -m "docs: add bootstrap guide (replaces howto.md)"
```

---

### Task 4: Create `docs/homelab.md`

**Files:**
- Create: `docs/homelab.md`

**Step 1: Write the file**

```markdown
# Homelab Services

All homelab services run on the `server` host (Raspberry Pi 4, aarch64-linux) using the `home-server` NixOS role, which composes: `common` + `server` + `media-server` + `smart-home` + `gaming-server` + `backup-server` + `backup`.

## Smart Home

### Home Assistant

Full home automation platform with the following sub-modules:

| Sub-module | Purpose |
|-----------|---------|
| **climate** | HVAC and climate control |
| **heatpump** | Heat pump integration and monitoring |
| **inverter** | Deye solar inverter monitoring |
| **night-schedule** | Scheduled automations (time-based) |
| **plugs** | Smart plug control (TV, Fireplace, Hall Mirror, Kids Door, PC) |
| **telegram-notifications** | Telegram bot alerts and notifications |
| **weather** | Weather data integration |
| **zigbee2mqtt** | Zigbee device bridge integration |

Configuration: `modules/nixos/services/smart-home/home-assistant/`

### Mosquitto MQTT

MQTT message broker for IoT device communication. Used by Home Assistant and Zigbee2MQTT.

Configuration: `modules/nixos/services/smart-home/mosquitto/`

### Zigbee2MQTT

Bridges Zigbee devices to MQTT using a SONOFF Zigbee adapter (Ember). Manages smart plugs, sensors, and other Zigbee devices.

Configuration: `modules/nixos/services/smart-home/zigbee2mqtt/`

### Zones & Devices

Zone-based automation (room/area definitions) and device management.

Configuration: `modules/nixos/services/smart-home/zones/`, `modules/nixos/services/smart-home/devices/`

## Media Stack

### Jellyfin

Media server for movies, TV shows, and music. Accessible via web interface.

### Sonarr & Radarr

Automated TV show (Sonarr) and movie (Radarr) management. Monitors for new episodes/releases and triggers downloads.

### Prowlarr

Torrent and Usenet indexer manager. Provides unified search across indexers for Sonarr and Radarr.

### qBittorrent

Torrent client. Downloads are organized into:
- `/data/torrents/Movies/`
- `/data/torrents/Series/`

Media files are served from:
- `/data/media/Movies/`
- `/data/media/Series/`

### MiniDLNA

UPnP/DLNA media server for streaming to TVs and other DLNA-compatible devices on the local network.

Configuration for all media services: `modules/nixos/services/media/`

## Networking

### Tailscale

VPN mesh network connecting all hosts. Provides secure access to homelab services from anywhere.

Configuration: `modules/nixos/services/networking/tailscale/`

### Nginx

Reverse proxy for internal services. Routes traffic to appropriate backends.

Configuration: `modules/nixos/services/networking/nginx/`

## Containers & Orchestration

### Podman

Container runtime (Docker-compatible, rootless). Used for running containerized services.

Configuration: `modules/nixos/services/virtualisation/podman/`

### k3s

Lightweight Kubernetes distribution. Supports both server and agent modes with token-based authentication.

Configuration: `modules/nixos/services/k3s/`

## Gaming

### Minecraft Server

Dedicated Minecraft server with configured ops, difficulty (hard), and game rules (keep inventory, mob griefing).

Configuration: `modules/nixos/services/gaming/minecraft-server/`

## Printing

### CUPS

Print server with network sharing support.

Configuration: `modules/nixos/services/printing/`

## Backup

Restic-based backup system with client-server architecture:

- **Restic client** (`modules/nixos/services/backup/restic/`) - Scheduled backups with retention policies
- **Restic server** (`modules/nixos/services/backup/restic-server/`) - REST API server for receiving backups

For detailed backup configuration, see [`modules/nixos/services/backup/README.md`](../modules/nixos/services/backup/README.md).

## Enabling Services

Services are typically enabled through the role system:

```nix
# In systems/aarch64-linux/server/default.nix
nix-config.roles.home-server.enable = true;  # Enables ALL server services
```

Individual services can also be toggled:

```nix
# Enable specific services
nix-config.services.media.jellyfin.enable = true;
nix-config.services.smart-home.home-assistant.enable = true;
nix-config.services.backup.restic.enable = true;
```

## Network Layout

All homelab devices have static IPs managed by the router (see [docs/router.md](router.md)):

| Device | IP | Purpose |
|--------|-----|---------|
| server | 10.0.0.40 | Main server (all services) |
| router | 10.0.0.1 | MikroTik gateway |
| cap1/cap2 | 10.0.0.11-12 | WiFi access points |
| monitor | 10.0.0.30 | Security camera |
| ajax | 10.0.0.31 | Security hub |
| tv / tv-wifi | 10.0.0.50-51 | Smart TVs |
| inverter | 10.0.0.52 | Solar inverter |
| heatpump | 10.0.0.53 | Heat pump |
```

**Step 2: Verify file was created**

Run: `wc -l docs/homelab.md`
Expected: ~140-160 lines

**Step 3: Commit**

```bash
git add docs/homelab.md
git commit -m "docs: add homelab services guide"
```

---

### Task 5: Create `docs/router.md`

**Files:**
- Create: `docs/router.md`

**Step 1: Write the file**

```markdown
# Router Management

The MikroTik RouterOS configuration is managed declaratively using [terranix](https://github.com/terranix/terranix) (Nix-based Terraform) and [OpenTofu](https://opentofu.org/).

## Architecture

```
Nix modules (infra/router/modules/*.nix)
    │
    ▼
terranix ── generates ──▶ Terraform JSON
    │
    ▼
OpenTofu ── applies via REST API ──▶ MikroTik RouterOS
```

## Configuration Structure

```
infra/router/
├── default.nix           # Terranix derivation and backup script
├── hosts.nix             # Static host/device definitions (IPs, MACs)
├── imports.nix           # Module imports
├── secrets.yaml          # SOPS-encrypted secrets
├── terraform.tfstate     # OpenTofu state (natively encrypted)
├── modules/
│   ├── provider.nix      # RouterOS Terraform provider config
│   ├── bridge.nix        # Bridge interface configuration
│   ├── capsman.nix       # CAPsMAN wireless access point controller
│   ├── dhcp.nix          # DHCP server and static leases
│   ├── dns.nix           # DNS server and upstream configuration
│   ├── firewall.nix      # Firewall rules, NAT, address lists
│   ├── interfaces.nix    # Network interfaces (ethernet, PPPoE, LTE, OpenVPN)
│   ├── system.nix        # System settings (hostname, timezone)
│   └── misc.nix          # Miscellaneous configuration
└── .terraform/           # OpenTofu providers (auto-managed)
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
```

**Step 2: Verify file was created**

Run: `wc -l docs/router.md`
Expected: ~130-140 lines

**Step 3: Commit**

```bash
git add docs/router.md
git commit -m "docs: add router management guide"
```

---

### Task 6: Fix `modules/nixos/services/backup/README.md`

**Files:**
- Modify: `modules/nixos/services/backup/README.md:32-39` (remove Documentation section)
- Modify: `modules/nixos/services/backup/README.md:150-158` (fix Support section)

**Step 1: Remove the "Documentation" section with broken links**

Remove lines 32-39:
```markdown
## Documentation

See the comprehensive documentation in the `docs/` directory:

- **[backup-with-restic.md](../../../docs/backup-with-restic.md)** - Complete guide with all features and options
- **[backup-examples.md](../../../docs/backup-examples.md)** - Ready-to-use configuration examples
- **[backup-quick-reference.md](../../../docs/backup-quick-reference.md)** - Quick reference for common commands
```

**Step 2: Fix the "Support" section**

Replace the Support section (lines 150-157) with:

```markdown
## Support

For issues or questions:
1. Check the restic documentation: https://restic.readthedocs.io/
```

**Step 3: Verify the fix**

Run: `grep -n "backup-with-restic\|backup-examples\|backup-quick-reference\|backup-setup-checklist" modules/nixos/services/backup/README.md`
Expected: No output (all broken links removed)

**Step 4: Commit**

```bash
git add modules/nixos/services/backup/README.md
git commit -m "docs: fix broken links in backup module README"
```

---

### Task 7: Rewrite `README.md`

**Files:**
- Modify: `README.md` (complete rewrite)

**Step 1: Write the new README**

```markdown
[![CI](https://github.com/aleks-sidorenko/nix-config/actions/workflows/ci.yml/badge.svg)](https://github.com/aleks-sidorenko/nix-config/actions/workflows/ci.yml)
[![Update Dependencies](https://github.com/aleks-sidorenko/nix-config/actions/workflows/update.yml/badge.svg)](https://github.com/aleks-sidorenko/nix-config/actions/workflows/update.yml)
[![Deploy Check](https://github.com/aleks-sidorenko/nix-config/actions/workflows/deploy-check.yml/badge.svg)](https://github.com/aleks-sidorenko/nix-config/actions/workflows/deploy-check.yml)

## About

Personal NixOS, nix-darwin, and home-manager configuration built on [snowfall-lib](https://github.com/snowfallorg/lib). Manages multiple systems across three architectures with declarative, role-based configuration, encrypted secrets, and opt-in persistence.

## Features

**Structure & Tooling**
- Modular organization with **snowfall-lib** and role-based composition
- Custom **Neovim** setup via **nixvim** (AI assistants, multi-language support)
- Multiple terminals (ghostty, kitty, alacritty, foot) and shells (fish, zsh)

**System Management**
- Declarative disk layout with **disko** (BTRFS + LUKS encryption)
- **Opt-in persistence** through **impermanence** + blank snapshot
- **SOPS-nix** secrets management with per-host age keys
- Remote deployment via **deploy-rs**, fresh installs via **nixos-anywhere**

**Desktop**
- **Hyprland** (hypridle, hyprlock, hyprpaper, pyprland) and **GNOME** desktop environments
- **Stylix** system-wide theming with **Catppuccin** color scheme
- Waybar, swaync, rofi, wlogout, kanshi

**Homelab**
- **Home Assistant** with 9 sub-modules (climate, heatpump, inverter, zigbee2mqtt, telegram, weather, plugs, night-schedule, zones)
- Media stack: **Jellyfin**, Sonarr, Radarr, Prowlarr, qBittorrent, MiniDLNA
- **k3s** (Kubernetes), **Podman**, **Tailscale** VPN, nginx, Minecraft server
- **Restic** backup with client-server architecture

**macOS**
- **nix-darwin** with Homebrew integration
- Colima/Lima/Rancher virtualization

**Infrastructure**
- **MikroTik RouterOS** managed via **terranix**/OpenTofu
- **CI/CD**: GitHub Actions (flake check, system builds, deploy check, security scan, weekly auto-update)
- Custom live ISO for NixOS installation

## Configurations

| Hostname | Architecture | Hardware | Role | OS | State |
|:--------:|:----------:|:---------|:----:|:--:|:-----:|
| `desktop` | x86_64-linux | Intel i7-2600K, GTX 560 Ti, 32GB | Desktop | NixOS | Active |
| `server` | aarch64-linux | Raspberry Pi 4 Model B, 8GB | Home Server | NixOS | Active |
| `vm` | x86_64-linux | Vagrant VM | Desktop (test) | NixOS | Active |
| `workbook` | aarch64-darwin | Apple Silicon MacBook | Work | macOS | Active |
| `minimal` | x86_64-install-iso | Any | Installer | NixOS ISO | - |

## Architecture

```
.
├── systems/          # System configs: desktop, server, vm, workbook, minimal
├── homes/            # Home-manager configs: alexander@desktop, alexander@vm, oleksandrsy@workbook
├── modules/
│   ├── nixos/        # NixOS modules (roles, services, desktops, hardware, disks, cli, security)
│   ├── home/         # Home-manager modules (roles, desktops, cli, development, browsers, media)
│   └── darwin/       # nix-darwin modules (roles, system, services, cli)
├── packages/         # Custom packages: nvim (nixvim), install ISO, wallpapers
├── overlays/         # Nixpkgs overlays
├── lib/              # Library: module helpers, context detection, deploy config, network utils
├── infra/            # Infrastructure-as-code: MikroTik router (terranix/OpenTofu)
└── scripts/          # Bootstrap and utility scripts
```

All modules use the `nix-config` namespace (`config.nix-config.*`). Roles compose related modules: e.g., `home-server` enables server + media-server + smart-home + gaming-server + backup.

See [docs/architecture.md](docs/architecture.md) for the full role hierarchy, library functions, and flake inputs.

## Usage

### Getting Started

```bash
git clone git@github.com:aleks-sidorenko/nix-config.git ~/.nix-config
cd ~/.nix-config
```

Prerequisites: Nix installed, git. For secrets management: `pass` configured, PGP key available.

### Local Deploy

```bash
# NixOS system configuration (uses hostname to find flake)
nh os switch

# Home-manager user configuration (uses hostname + username)
nh home switch

# Alternative without nh
sudo nixos-rebuild switch --flake .
```

### Remote Deploy

```bash
just deploy <hostname>                     # Deploy (remote build by default)
just deploy <hostname> --dry-run           # Preview changes
just deploy router                         # Deploy MikroTik router config
```

For fresh installations on new hardware, see [docs/bootstrap.md](docs/bootstrap.md).

### Secrets

Secrets are encrypted with [SOPS](https://github.com/getsops/sops) using age keys derived from each host's SSH key.

```bash
just secrets-list                          # List all secrets
just secrets-edit nixos                    # Edit NixOS secrets
just secrets-edit home                     # Edit home-manager secrets
```

Secrets files:
- `modules/nixos/secrets.yaml` - system secrets (user passwords, API keys, WiFi)
- `modules/home/secrets.yaml` - user secrets
- `infra/router/secrets.yaml` - router secrets

To add a new host's key, see [docs/bootstrap.md](docs/bootstrap.md#adding-a-new-host-to-sops).

### Maintenance

```bash
just update                                # Update flake inputs
just cleanup                               # Garbage collect old generations
just lint                                  # Format + statix + deadnix
just lint-fix                              # Auto-fix linting issues
just check                                 # nix flake check
just info                                  # Show system info
just disk-usage                            # Show nix store usage
```

## Development

```bash
# Typical workflow
just format                                # Format nix files
just lint-check                            # Verify code quality (CI-friendly)
just build-test                            # Test build without switching
just deploy <hostname>                     # Deploy
```

CI runs on push/PR to master: flake check, formatting, security scan (Trivy). Full system and home-manager builds run on master branch only. Flake inputs are auto-updated weekly.

## Documentation

| Document | Description |
|----------|-------------|
| [docs/architecture.md](docs/architecture.md) | Repository structure, role hierarchy, library functions, flake inputs |
| [docs/bootstrap.md](docs/bootstrap.md) | Fresh installation, bootstrap process, disk formatting, RPi4 setup |
| [docs/homelab.md](docs/homelab.md) | Homelab services overview, network layout |
| [docs/router.md](docs/router.md) | MikroTik router management with terranix/OpenTofu |
| [docs/references.md](docs/references.md) | Inspirations, NixOS resources, credits |

## Credits

See [docs/references.md](docs/references.md) for inspirations, resources, and wallpaper credits.
```

**Step 2: Verify the new README**

Run: `wc -l README.md`
Expected: ~190-210 lines

Run: `grep -c "docs/" README.md`
Expected: 10+ (links to docs/ files)

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs: rewrite README with features, all configs, usage, and docs index"
```

---

### Task 8: Delete `docs/howto.md`

**Files:**
- Delete: `docs/howto.md`

**Step 1: Verify bootstrap.md exists and covers all howto.md content**

Checklist - verify each topic from howto.md exists in bootstrap.md:
- [ ] SOPS secret addition (user password) → bootstrap.md "Adding a User Password to SOPS" section
- [ ] Bootstrap via nixos-anywhere → bootstrap.md "Quick Start" and "What Bootstrap Does" sections
- [ ] RPi4 specifics → bootstrap.md "Raspberry Pi 4" section
- [ ] VM setup → bootstrap.md "VM (Testing)" section
- [ ] Disko formatting → bootstrap.md "Disk Formatting with Disko" section

Run: `grep -c "mkpasswd\|nixos-anywhere\|bootstrap-rpi\|vagrant\|bootstrap-disk" docs/bootstrap.md`
Expected: 5+ matches

**Step 2: Delete the file**

```bash
git rm docs/howto.md
```

**Step 3: Verify no remaining links to howto.md**

Run: `grep -r "howto.md" --include="*.md" .`
Expected: No output (no remaining references)

**Step 4: Commit**

```bash
git commit -m "docs: remove howto.md (replaced by bootstrap.md)"
```
