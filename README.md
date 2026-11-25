<p align="center">
  <a href="https://github.com/aleks-sidorenko/nix-config/actions/workflows/ci.yml"><img src="https://github.com/aleks-sidorenko/nix-config/actions/workflows/ci.yml/badge.svg" alt="CI"/></a>
  <a href="https://nixos.org"><img src="https://img.shields.io/badge/NixOS-26.05-5277C3?logo=nixos&logoColor=white" alt="NixOS 26.05"/></a>
  <a href="https://den.denful.dev"><img src="https://img.shields.io/badge/built_with-den-informational?logo=nixos&logoColor=white" alt="Built with den"/></a>
  <a href="https://github.com/mightyiam/dendritic"><img src="https://img.shields.io/badge/pattern-dendritic-informational?logo=nixos&logoColor=white" alt="Dendritic pattern"/></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/aleks-sidorenko/nix-config" alt="License"/></a>
  <a href="https://github.com/aleks-sidorenko/nix-config/commits/master"><img src="https://img.shields.io/github/last-commit/aleks-sidorenko/nix-config/master" alt="Last commit"/></a>
  <a href="https://github.com/aleks-sidorenko/nix-config/stargazers"><img src="https://img.shields.io/github/stars/aleks-sidorenko/nix-config" alt="Stars"/></a>
</p>

# nix-config

Personal NixOS configuration built on [den](https://den.denful.dev), the
aspect-oriented framework for the [dendritic pattern](https://github.com/mightyiam/dendritic).
It runs a home server, the VMs that test it in CI, and a Mac workstation.

## Highlights

- **Aspects, not hosts.** Every file under `modules/` is a flake-parts module
  that [import-tree](https://github.com/denful/import-tree) loads; each feature
  is an aspect that hosts and roles include.
- **Generated `flake.nix`.** Each module declares its own inputs through
  [flake-file](https://github.com/denful/flake-file); CI fails if the flake is stale.
- **Impermanent root.** The btrfs root is wiped on every boot, and each service
  declares the state it keeps.
- **Homelab.** A media stack behind an nginx ingress on the tailnet, a
  Minecraft server, and offsite backups with restic.
- **Secrets.** SOPS with age keys derived from each host's SSH host key.
- **Tested end to end.** Eval tests, parity checks against the previous tree,
  and a full install test for every VM host, all in CI.

## Hosts

| Host | Platform | What it is | Role |
| --- | --- | --- | --- |
| `server` | x86_64-linux | Mini PC (Intel Core i3-7020U, 8 GB RAM, 2 TB SATA SSD), Wi-Fi only | `roles.home-server` |
| `server-vm` | x86_64-linux | QEMU guest standing in for `server`, install-tested in CI | `roles.home-server` |
| `workbook` | aarch64-darwin | Work MacBook with its user's home | `roles.workstation` |
| `base-vm` | x86_64-linux | Bare QEMU guest with an encrypted disk, install-tested in CI | `roles.base` |
| `iso-x86_64` | x86_64-linux | Bootable USB image: the user autologins with core tools, root takes the owner's key | `roles.core` |

Only `server` is a deploy target. Switch `workbook` on the Mac with `nix run .#workbook -- switch`.
Write the image to a USB stick with `just iso-fetch iso-x86_64` (CI builds it)
and `just iso-write iso-x86_64 /dev/diskN`.

## Layout

```
modules/
├── den.nix         # den and flake setup: host/user schema, defaults, inputs
├── flake/          # outputs and tooling: deploy-rs, nh, install tests, eval tests, devshell, naming check
├── hosts/          # one folder per host, plus home-servers.nix (what server and server-vm share)
├── roles/          # bundles of aspects: core, base, server, media-server, home-server, workstation
├── system/         # boot, iso, nix, nixpkgs, locale, networking, NetworkManager, headless
├── storage/        # disko layout, impermanence and the undeclared-state guard
├── security/       # ssh, sops, sudo, user passwords, authorized keys
├── services/       # tailscale, nginx, restic, the media stack, minecraft, openvpn
├── cli/            # terminal tools: core, fish, nvim, ghostty, media, utils
├── dev/            # git, direnv, per-project stacks, bazel, containers, k8s
├── gui/            # GUI apps: chrome, communication, photo and video, minecraft, raycast
├── hardware/       # qemu-guest
└── users/          # alexander
packages/           # our own programs, plain callPackage files: disk-report, iso-write, media-tools
identities/         # per-person public keys (see identities/README.md)
secrets/            # SOPS-encrypted: nixos.yaml, darwin.yaml; hosts/ holds each host's SSH identity
```

- The aspect path mirrors the file path: `modules/services/nginx.nix` defines
  `den.aspects.services.nginx`.
- `flake.nix` is generated: run `just flake-write` after changing an input, and
  never edit it by hand. `.sops.yaml` is generated too (`just sops-write`).

## Usage

- Everything runs through `just` and the dev shell (`nix develop`); recipes
  enter the shell themselves when needed.
- On a host itself, `nix run .#<host> -- switch` runs nh for that host.

| Command | What it does |
| --- | --- |
| `just check` | Format check, lint (statix, deadnix) and `nix flake check`, including the eval tests |
| `just format [path]` | Format with nixfmt (writes) |
| `just lint-fix` | Apply statix and deadnix fixes |
| `just build <host>` | Build a host's system without switching |
| `just deploy <host> [args]` | Deploy with deploy-rs, building on the target; `--boot` activates on the next boot |
| `just bootstrap-nixos <host> <address>` | Install a NixOS host from the installer image, keeping its identity in the repo |
| `just bootstrap-darwin <host>` | Give the Mac it runs on its identity from the repo, or adopt its own |
| `just vm-test <host>` | Run a VM host's install test (x86_64 Linux with KVM only; otherwise CI runs it) |
| `just flake-write` | Regenerate `flake.nix` |
| `just sops-write` | Regenerate `.sops.yaml` from the hosts and their keys |
| `just update [input]` | Update flake inputs |

## Secrets

- System secrets live in `secrets/nixos.yaml` and `secrets/darwin.yaml`, encrypted with
  [SOPS](https://github.com/getsops/sops) to the owner's PGP key and the age
  key of every host that reads them.
- A host's age key comes from its SSH host key. The key is kept in the repo:
  `secrets/hosts/<host>.pub` in plaintext, the private key in
  `secrets/hosts/<host>.yaml`, encrypted to the owner only, so a reinstall
  keeps the identity.
- `.sops.yaml` is generated from the hosts' configs and those keys
  (`just sops-write`); `just check` fails when it is stale.
- Edit with `sops secrets/nixos.yaml`. New hosts get their key and recipients
  from `just bootstrap-nixos` / `just bootstrap-darwin`.

## Testing

- **Eval tests** (`evalTests` in each module, run by `just check`) pin
  behaviour next to the code that owns it.
- **Parity tests** compare `server` with snapshots of the snowfall tree's
  evaluated config, so a port can't silently change the live box.
- **Install tests** (`checks.x86_64-linux.install-<host>`) install each VM host
  into a disko test VM the way a real install does, then reboot and
  power-cycle it. They check that:
  - root is wiped and persisted state survives;
  - every service and site comes up, and no unit failed;
  - no service wrote state that is neither persisted nor declared throwaway.

CI ([`ci.yml`](.github/workflows/ci.yml)) runs all of them on pushes and pull
requests to `master`, then builds `server`.

## Documentation

| Document | What it covers |
| --- | --- |
| [docs/architecture.md](docs/architecture.md) | How the den layout fits together: entities, aspects, roles, settings, quirks, storage, tests, deploys |
| [docs/bootstrap.md](docs/bootstrap.md) | First-time setup, in order: operator, credentials, tailnet, router, NixOS hosts, Macs, reinstalling and retiring |
| [docs/homelab.md](docs/homelab.md) | What `server` runs, where its state lives, ingress, backups and restore, deploys and rollback |
| [AGENTS.md](AGENTS.md) | Conventions and step-by-step recipes for adding features, hosts, users, settings and quirks |
| [identities/README.md](identities/README.md) | Public key material per person |

## Status

This tree replaces the earlier snowfall-lib configuration, which stays
available at the [`v1`](https://github.com/aleks-sidorenko/nix-config/tree/v1)
tag. The rewrite lands in slices, tracked in
[#272](https://github.com/aleks-sidorenko/nix-config/issues/272).

- **Ported:** the base system, the server role, everything `server` runs, the
  macOS `workbook` with its home, the DNS, router, storage and tailnet stacks, the
  installer ISO, and bootstrapping new hosts.

## License

MIT, see [LICENSE](LICENSE).
