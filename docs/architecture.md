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
│   ├── media-tools/                # Media inspection/recovery utilities
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
| **desktop** | common, development, media, mobile, gaming, communication, router-manager | Teamviewer, GNOME, Chrome, Firefox, Wayland tools |
| **work** | common, development, router-manager | Chrome, Teamviewer (macOS-oriented) |
| **development** | - | VS Code, Cursor, IDEA, languages (haskell, rust, python, go, typescript, scala, java), Bazel, MySQL, Testcontainers, AI (copilot, claude-code), Podman, k8s |
| **media** | - | VLC, Shotwell |
| **mobile** | - | MTP tools (Android integration) |
| **gaming** | - | Minecraft |
| **communication** | - | Telegram, Viber |
| **router-manager** | - | Winbox (MikroTik management) |

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

### `lib/misc` - Miscellaneous Helpers

| Function | Description |
|----------|-------------|
| `mkMimeAssociations app types` | Build an attrset associating each MIME `type` with `app` (for default-application config) |
| `mkId parts` | Join `parts` with `_` (underscore-separated identifier) |
| `mkFriendlyName parts` | Join `parts` with `/` (slash-separated friendly name) |

> **Note:** Router/terranix derivation helpers previously lived in `lib/terraform`. That logic now lives in the standalone [`nix-routeros`](https://github.com/aleks-sidorenko/nix-routeros) flake (`mkRouterDerivation`) — see [docs/router.md](router.md).

## Multi-Architecture Support

| Architecture | Systems | Description |
|-------------|---------|-------------|
| `x86_64-linux` | desktop, vm | Desktop workstation, test VM |
| `aarch64-linux` | server | Raspberry Pi 4 home server |
| `aarch64-darwin` | workbook | macOS Apple Silicon laptop |
| `x86_64-install-iso` | minimal | Custom NixOS installer image (`nix build .#install-isoConfigurations.minimal`) |

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
| nix-nvim | latest | First-party Neovim config flake (extracted; sourced by `modules/home/cli/editors/nvim`) |
| terranix | latest | Terraform/OpenTofu in Nix |
| nix-routeros | latest | First-party MikroTik RouterOS flake (extracted; `mkRouterDerivation`) |
| Hyprland ecosystem | latest | hypr-contrib, hyprcursor, pyprland, hyprpanel |
| nix-homebrew | latest | Homebrew integration for macOS |
| catppuccin | latest | Catppuccin color scheme |
| catppuccin-obs | latest | Catppuccin theme for OBS |
