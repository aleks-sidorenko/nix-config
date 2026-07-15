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
| **minimal** | - | Bare base: SSH, Nix, locale, networking, fish shell |
| **common** | minimal | SOPS, boot, filesystems, impermanence, GitHub-authed Nix |
| **graphical** | common, gaming, backup | Shared graphical suite: nh, nix-ld, stylix, GNOME, VirtualBox, Podman, hibernation |
| **desktop** | graphical | Root role for the desktop host |
| **homebook** | graphical, laptop | Root role for the shared family laptop |
| **laptop** | - | Laptop power management (power-profiles-daemon, upower) |
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
| **graphical** | common, media, mobile, gaming, communication, router-manager | Shared graphical suite: Teamviewer, GNOME, Chrome, Firefox, Wayland tools |
| **desktop** | graphical, development | Root role for the desktop host (graphical + development) |
| **homebook** | graphical | Root role for the shared family laptop (graphical, no development) |
| **child** | common | Restricted account: Minecraft only, no browser |
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

## Users & Identities

### Multiple users per host

Accounts are declared uniformly through `nix-config.users` (NixOS), one entry per
account including the primary:

```nix
nix-config.users = {
  alexander = { primary = true; admin = true; };  # profile defaults to "adult"
  dima       = { profile = "child"; };            # no wheel; Minecraft-only home
};
```

- Exactly one entry is `primary = true`. Profiles (`adult`/`child`) set group
  presets; `admin` adds `wheel`.
- `nix-config.user` (singular) is a **derived alias** of the primary, kept so
  existing references (doas, greetd, ssh, virtualisation group injection) keep
  working. It is not declared directly.
- Per-user home environments are the usual snowfall `homes/<user>@<host>/`.

### Identities (public key material)

Each **person's** public key material is colocated in a single top-level folder,
so adding someone is one copy-paste — nothing spread across modules:

```
identities/
  <name>/
    gpg.pub.asc   # GPG public key (ASCII-armored)
    gpg.key-id    # GPG key ID exposed as the SSH key (gpg-agent = ssh-agent)
    ssh.pub       # SSH public key (the GPG authentication subkey)
```

- **Which** identity a home uses is set by `nix-config.security.identity.name`
  (a home option that defaults to the account username). Override it when one
  person has several accounts — e.g. `oleksandrsy@workbook` sets it to
  `"alexander"` to reuse that key material.
- The `gpg`, `ssh`, and git-signing home modules — plus each host's
  `authorizedKeys` — resolve their key material via
  [`lib/identity`](#libidentity---identity-key-material)
  (`resolveIdentityByName` is the single shared entry point across NixOS,
  darwin, and home).
- A person with **no** folder (e.g. a child account) simply gets no key
  material — no import, no `~/.ssh` key, git signing off. Adding
  `identities/<name>/` later grants it with zero code changes.
- Only **public** material lives here; the private GPG key (the single secret
  root) is imported out-of-band at bootstrap. See
  [identities/README.md](../identities/README.md) and
  [docs/bootstrap.md](bootstrap.md).

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
| `identityName config` | Get the identity name regardless of context (honors the `security.identity.name` override, e.g. `oleksandrsy → alexander`) |
| `homeDir config` | Get home directory regardless of context |
| `homeConfig config` | Access home-manager config from either context |

### `lib/identity` - Identity Key Material

Resolves a person's public key material from the top-level `identities/` folder
(see [Users & Identities](#users--identities)).

| Function | Description |
|----------|-------------|
| `identityDir name` | Absolute path to `identities/<name>/` |
| `identityFile name file` | Absolute path to a file in the identity's folder, or `null` if absent |
| `resolveIdentityByName name` | Resolve a name → `{ name; available; gpgPublicKeyFile; gpgKeyId; sshPublicKeyFile; sshPublicKey; }` (the shared entry point used by NixOS, darwin, and home) |
| `resolveIdentity config` | Wrapper reading the name from a home config's `security.identity.name` |

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
| `x86_64-linux` | desktop, homebook, vm | Desktop workstation, shared family laptop, test VM |
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
