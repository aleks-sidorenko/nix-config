# modules/

Every `.nix` file here is a [flake-parts](https://flake.parts) module, loaded by
[import-tree](https://github.com/vic/import-tree). The layout follows the
[dendritic pattern](https://github.com/mightyiam/dendritic), with
[Doc-Steve/dendritic-design-with-flake-parts](https://github.com/Doc-Steve/dendritic-design-with-flake-parts)
as the worked example. Design: `docs/superpowers/specs/2026-11-10-dendritic-skeleton-design.md`.
Tracking issue: #267.

## Rules

1. **Every `.nix` file is a flake-parts module.** Paths with a `_` prefix are
   skipped. Use that prefix for plain NixOS/darwin/HM modules (`_hardware.nix`,
   `_disks.nix`), terranix configs, `callPackage` files and raw data.
2. **One directory per feature, named after the feature.** The feature sets every
   class it touches: `flake.modules.{nixos,darwin,homeManager,generic}.<feature>`.
   Inside the directory, split files however suits the feature (`nixos.nix`,
   `darwin.nix`, `home.nix`, …). Every file there adds to the same aspect.
3. **The path is for people. The aspect name is the leaf.**
   `services/media/jellyfin/` defines `flake.modules.nixos.jellyfin`. Group
   directories (`services/media/`) can nest as deep as needed. Leaf names are
   unique across the tree:
   - **Same name in several classes → one feature.** For example, `podman` on
     nixos, darwin and home.
   - **Different features that clash → qualify one.** A name too generic on its
     own (`tools`, `code`, `defaults`) takes its group or platform as a prefix:
     `media-tools`, `vscode`, `macos-defaults`.
   - **Feature directories don't nest.** The one exception is plugins of a feature
     (Home Assistant integrations). They live inside it and are named
     `<parent>-<leaf>`, e.g. `home-assistant-climate`.
4. **Importing is enabling.** No `enable` options that only gate a module, and no
   `mkIf cfg.enable`. Real settings stay options under `nix-config.*`.
5. **Imports are explicit and never conditional.** Never put `mkIf` around
   `imports`. A platform difference goes in the content (`lib.mkMerge` +
   `lib.mkIf pkgs.stdenv.isDarwin …`, not `//`) or in the class parts. Imports
   may overlap. Every aspect carries a `key` (`nix/modules.nix`), so when two
   roles both import `system-server`, it is evaluated once. Plain modules that
   aren't aspects have no key, so import them from exactly one place.
6. **You can't subtract an import, so roles stay small.** Anything a host might
   not want is imported by the host, not baked into a role.
7. **Types for the base environment, roles for purpose, hosts kept tiny.**
   - **System types** (`system/types/`): `system-core` → `system-common` →
     `system-server` / `system-desktop`. Hosts and users import them.
   - **Roles** (`roles/`) describe what a machine is for, and may import the type
     they need.
   - **Device pieces** (`hardware/devices/`) are features, not types.
   - A host is usually one role, its user, its hardware and host-only settings.
8. **Hosts and users are features.** A host owns its bare name. Users come from
   `config.factory.user`.
9. **No `specialArgs`.** Shared facts live in `constants` (read from `config`).
   Flake inputs come from the top-level module's `inputs`.
10. **`lib/` holds functions only.**

## Layout

| Directory | Holds |
|---|---|
| `nix/` | Flake plumbing: flake-parts, nixpkgs, home-manager, plumbing collector, formatter, dev shell, eval tests |
| `lib/` | `flake.lib.*` (`mkNixos`, `mkDarwin`) and the internal `builders` |
| `constants/` | Typed shared facts, mirrored read-only into every class |
| `factory/` | `config.factory.*`: functions that build per-class modules |
| `system/` | Base OS features, disks, and the `system/types/` chain |
| `hardware/` | Hardware support and device features |
| `security/` | Secrets, SSH, GPG, auth |
| `cli/` | Shells, editors, terminals, CLI tools |
| `desktops/` | Window managers, desktop environments, their addons, styling |
| `apps/` | Applications a user runs: browsers, communication, media, productivity, games |
| `development/` | Languages, platforms, build tools, dev editors, AI tools |
| `services/` | Daemons and servers: networking, media, backup, gaming, smart-home, virtualisation |
| `roles/` | Purpose bundles that compose features |
| `users/` | One feature per person, plus profiles |
| `hosts/` | One directory per machine |
| `infra/` | Terranix stacks (router, dns, storage, tailnet) |
| `packages/` | Custom packages |

## Where existing modules go

Paths on the left are relative to `modules/` on `master`. Each domain README has
more examples.

| On `master` | Here |
|---|---|
| `{nixos,darwin,home}/system/*` (boot, fs, locale, networking, nix, power, hibernation, defaults, homebrew) | `system/<feature>/`, one feature across all classes |
| `nixos/disks/{disko,impermanence}` | `system/disks/<feature>/` |
| `*/roles/minimal` | `system/types/system-core/` |
| `*/roles/common` | `system/types/system-common/` |
| `nixos/roles/server` | `system/types/system-server/` |
| `*/roles/{desktop,graphical}` | `system/types/system-desktop/` |
| `*/roles/{laptop,homebook,macbook,phone}`, `nixos/hardware/phone` | `hardware/devices/<feature>/` |
| `nixos/hardware/*` | `hardware/<feature>/` |
| `*/security/*` | `security/<feature>/` |
| `*/cli/{shells,editors,terminals,tools}/*` | `cli/<group>/<feature>/`; `*/default` selectors become `default-<x>` features (see `cli/README.md`) |
| `*/desktops/*`, `*/styles/stylix` | `desktops/…`; stylix at `desktops/styles/stylix/` |
| `*/browsers/*`, `*/communication/*`, `*/media/*` (apps), `home/productivity/*`, `home/games/*` | `apps/<group>/<feature>/` |
| `home/development/*` | `development/<group>/<feature>/` |
| `*/services/*`, `home/virtualization/*` | `services/<group>/<feature>/` |
| `*/roles/*` (purpose: home-server, media-server, work, agent-host, …) | `roles/<role>/` |
| `nixos/users`, `darwin/users`, `home/user` | `factory/user.nix` + `users/<name>/` |
| `nixos/users/child-lockdown`, `home/roles/child`, `home/desktops/gnome/profiles/*` | `users/profiles/<profile>/` |
| `systems/<arch>/<host>`, `homes/<arch>/<user>@<host>` | `hosts/<host>/` |
| `lib/defaults` | `constants/` |
| `lib/*` (functions) | `lib/`, only when used |
| `infra/<stack>` (repo root) | `infra/<stack>/` |
| `packages/<name>` (repo root), `overlays/*` | `packages/<name>/`; overlays in `nix/` |

## How to add

**A feature.** Create `<domain>/<group>/<feature>/` with a flake-parts module:

```nix
{ ... }:
{
  flake.modules.nixos.<feature> = { pkgs, ... }: { /* … */ };
  flake.modules.homeManager.<feature> = { /* … */ };
}
```

**A host.** Create `hosts/<host>/<host>.nix` (plus `_hardware.nix`, `_disks.nix`):

```nix
{ inputs, ... }:
{
  flake.modules.nixos.<host> = {
    imports = with inputs.self.modules.nixos; [ <role> <user> ./_hardware.nix ];
    system.stateVersion = "…";
  };
  flake.nixosConfigurations.<host> = inputs.self.lib.mkNixos "x86_64-linux" "<host>";
}
```

Darwin is the same, with `mkDarwin "aarch64-darwin"`. Home-manager runs inside
the host; there are no standalone `homeConfigurations`.

**A user.** Create `users/<name>/<name>.nix`:

```nix
{ config, ... }:
let user = config.factory.user { name = "<name>"; admin = true; };
in {
  flake.modules.nixos.<name> = user.nixos;
  flake.modules.darwin.<name> = user.darwin;
  flake.modules.homeManager.<name> = { /* the person's home config */ };
}
```

**A constant.** Declare it in `constants/_options.nix` (with a type and a
description), and set it once in a `constants/*.nix` file. Read it as
`config.constants.…` anywhere. A feature applies it with `mkDefault`. A host
that must deviate overrides the real option, never the constant.

**A test.** Add an `evalTests.<name> = { expr = …; expected = …; };` entry
next to the code. `nix flake check` runs them all.
