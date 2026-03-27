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

### Build Installer ISO

```bash
nix build .#install-isoConfigurations.minimal   # Build minimal NixOS installer ISO
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
