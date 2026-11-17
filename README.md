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

Personal NixOS configuration built on [den](https://den.denful.dev/), a
dendritic layout on flake-parts: every file under `modules/` is a module that
[import-tree](https://github.com/denful/import-tree) loads, and each feature is
an aspect that hosts and roles include.

It runs a home server: a media stack behind an nginx ingress on the tailnet,
offsite restic backups and a Minecraft server, on an impermanent btrfs root
whose state is declared per service.

## Hosts

| Host | Platform | What it is | Role |
| --- | --- | --- | --- |
| `server` | x86_64-linux | Mini PC (Intel Core i3-7020U, 8 GB RAM, 2 TB SATA SSD), Wi-Fi only | `roles.home-server` |
| `server-vm` | x86_64-linux | QEMU guest standing in for `server`, install-tested in CI | `roles.home-server` |
| `base-vm` | x86_64-linux | Bare QEMU guest with an encrypted disk, install-tested in CI | `roles.base` |

Only `server` is a deploy target.

## Layout

```
modules/
├── den.nix         # den and flake setup: host/user schema, defaults, inputs
├── flake/          # outputs and tooling: deploy-rs, install tests, eval tests, devshell, naming check
├── hosts/          # one folder per host, plus home-servers.nix (what server and server-vm share)
├── roles/          # bundles of aspects: base, server, media-server, home-server
├── system/         # boot, nix, nixpkgs, locale, networking, NetworkManager, headless
├── storage/        # disko layout, impermanence and the undeclared-state guard
├── security/       # ssh, sops, sudo, user passwords, authorized keys
├── services/       # tailscale, nginx, restic, the media stack, minecraft
├── hardware/       # qemu-guest
└── users/          # alexander
identities/         # per-person public keys (see identities/README.md)
secrets/nixos.yaml  # SOPS-encrypted system secrets
```

`flake.nix` is generated from the `flake-file.inputs` each module declares;
run `just flake-write` after changing one and never edit it by hand.

## Usage

Everything runs through `just` and the dev shell (`nix develop`); recipes enter
the shell themselves when needed.

| Command | What it does |
| --- | --- |
| `just check` | Format check, lint (statix, deadnix) and `nix flake check`, including the eval tests |
| `just format [path]` | Format with nixfmt (writes) |
| `just lint-fix` | Apply statix and deadnix fixes |
| `just build <host>` | Build a host's system without switching |
| `just deploy <host> [args]` | Deploy with deploy-rs, building on the target; `--boot` activates on the next boot |
| `just vm-test <host>` | Run a VM host's install test (x86_64 Linux with KVM only; otherwise CI runs it) |
| `just flake-write` | Regenerate `flake.nix` |
| `just update [input]` | Update flake inputs |

On a host itself, `nix run .#<host> -- switch` runs nh for that host.

### Secrets

System secrets live in `secrets/nixos.yaml`, encrypted with
[SOPS](https://github.com/getsops/sops) to the age keys in `.sops.yaml`: each
host's key comes from its SSH host key, kept under `/persist/etc/ssh`. Edit
with `sops secrets/nixos.yaml`; after adding a host's key,
`sops updatekeys secrets/nixos.yaml`.

## Testing

- **Eval tests** (`evalTests` in each module, run by `just check`) pin
  behaviour next to the code that owns it.
- **Parity tests** compare `server` with the evaluated config of the
  snowfall tree it replaces, so a port can't silently change the live box.
- **Install tests** (`checks.x86_64-linux.install-<host>`) install each VM
  host into a disko test VM the way a real install does, reboot it,
  power-cycle it, and check that root is wiped, persisted state survives,
  every service and site comes up, no unit failed, and no service wrote state
  that is neither persisted nor declared throwaway.

CI (`.github/workflows/ci.yml`) runs all of them on pushes and pull requests
to `master`, then builds `server`.

## Documentation

| Document | What it covers |
| --- | --- |
| [docs/architecture.md](docs/architecture.md) | How the den layout fits together: entities, aspects, roles, settings, quirks, storage, tests, deploys |
| [docs/homelab.md](docs/homelab.md) | What `server` runs, where its state lives, ingress, backups and restore, deploys and rollback |
| [AGENTS.md](AGENTS.md) | Conventions and step-by-step recipes for adding features, hosts, users, settings and quirks |
| [identities/README.md](identities/README.md) | Public key material per person |

## Status

This tree is a rewrite of the earlier snowfall-lib configuration, done in
slices ([#272](https://github.com/aleks-sidorenko/nix-config/issues/272)).
Ported so far: the base system, the server role, and everything `server` runs.
Not yet ported: the macOS workbook, home-manager modules beyond the user's
shell, the installer ISO, bootstrap scripts, and the infrastructure stacks
(router, DNS, storage bucket, tailnet policy).

## License

MIT — see [LICENSE](./LICENSE).
