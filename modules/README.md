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
2. **One file per feature, or one directory once it needs more files.** A
   feature is `<feature>.nix`. It sets every class it touches:
   `flake.modules.{nixos,darwin,homeManager,generic}.<feature>`, side by side in
   one file. Once it needs a second file (`_package.nix`, `_hardware.nix`, or
   parts split per class), it becomes a `<feature>/` directory. Each file in it
   adds to the same aspect. In these READMEs, a path like `cli/tools/bat/` means
   `cli/tools/bat.nix` or `cli/tools/bat/`, whichever fits.
3. **The path is for people. The aspect name is the leaf.**
   `services/media/jellyfin/` defines `flake.modules.nixos.jellyfin`. Group
   directories (`services/media/`) can nest as deep as needed. Leaf names are
   unique across the tree:
   - **Same name in several classes → one feature.** For example, `podman` on
     nixos, darwin and home.
   - **Names come from `master`**, except the renames listed under
     [Renamed features](#renamed-features). A new clash gets a row there; don't
     rename on the spot.
   - **Feature directories don't nest.** Files inside a feature directory are
     parts of that one aspect.
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
   - **System types** (`system/types/`): `system-minimal` → `system-common` →
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
11. **A package lives in the feature that uses it.** Its `callPackage` file is
    `_package.nix` in the feature directory. The feature exports it as
    `perSystem.packages.<name>` and installs it with
    `pkgs.callPackage ./_package.nix { }`. There is no overlay and no
    `pkgs.nix-config.*`. A package gets its own `packages/<name>/` directory only
    once a second feature needs it.
12. **A factory lives with its callers.** `config.factory.<name>` holds
    functions that build modules from parameters (Doc-Steve's *factory aspect*),
    for features that share a shape but can't share one aspect. Keys are flat
    and unique, like aspect names. The factory goes in `<name>-factory.nix` in
    the directory of the features that call it (`users/user-factory.nix`,
    `services/media/arr-factory.nix`), and moves up only once callers elsewhere
    need it.

## Layout

Each row's test decides where a feature goes. Check the rows in order; the first
one that fits wins.

| Directory | A feature belongs here if… |
|---|---|
| `nix/`, `lib/`, `constants/` | it's plumbing, a helper or shared data, not something a host turns on |
| `hosts/` | it describes one machine |
| `users/` | it describes one person, or a profile of people (`child`) |
| `roles/` | it bundles other features for a purpose (what a machine is for) |
| `security/` | it handles secrets, keys or authentication (`sops`, `ssh`, `gpg`, `pam`) |
| `hardware/` | it supports a piece of hardware (drivers, firmware) or describes a kind of device |
| `services/` | it runs a daemon or VM that other things connect to (`tailscale`, `nginx`, `podman`) |
| `system/` | the OS itself needs it (boot, storage, networking, nix, compatibility), or it's a system type |
| `development/` | only someone writing code needs it (languages, build tools, IDEs, `k8s`, `claude-code`) |
| `cli/` | it's the shell, the terminal, the terminal editor, or a command-line tool for everyday use (`git`, `zellij`, `nh`) |
| `apps/` | it's an application for a non-coding purpose: browsing, chat, media, office, games |
| `desktops/` | it shapes the graphical session itself: WM, bar, launcher, theme, monitor layout |
| `infra/` | it's a terranix stack, not a host feature |

## Renamed features

Every other feature keeps its name from `master`. The renames are:

| On `master` | Renamed to | Why |
|---|---|---|
| `home/development/editors/code` | `vscode` | `code` is too generic |
| `home/media/tools` | `media-tools` | `tools` is too generic; matches its package |
| `home/media/qbittorrent` | `qbittorrent-client` | clashes with the `qbittorrent` service |
| `darwin/system/defaults` | `macos-defaults` | `defaults` is too generic |
| `*/roles/minimal`, `common`, `server`, `desktop` + `graphical` | `system-minimal`, `system-common`, `system-server`, `system-desktop` | system types carry the `system-` prefix |
| `home/roles/agent` + `*/roles/agent-host` | `agent-host` | one feature across classes |
| `nixos/system/nix`'s `githubAuth` option | `nix-github-auth` | importing is enabling; needs `sops`, which the installer lacks |

## Where existing modules go

Not ported: smart-home (all of `nixos/services/smart-home/*` and `nixos/roles/smart-home`) and `server-vm`. See #267.

Paths on the left are relative to `modules/` on `master`. Each domain README has
more examples.

| On `master` | Here |
|---|---|
| `{nixos,darwin,home}/system/*` (boot, fs, locale, networking, nix, power, hibernation, defaults, homebrew) | `system/<feature>/`, one feature across all classes |
| `nixos/disks/{disko,impermanence}` | `system/disks/<feature>/` |
| `*/roles/minimal` | `system/types/system-minimal/` |
| `*/roles/common` | `system/types/system-common/` |
| `nixos/roles/server` | `system/types/system-server/` |
| `*/roles/{desktop,graphical}` | `system/types/system-desktop/` |
| `*/roles/{laptop,homebook,macbook,phone}`, `nixos/hardware/phone` | `hardware/devices/<feature>/` |
| `nixos/hardware/*` | `hardware/<feature>/` |
| `*/security/*` | `security/<feature>/` |
| `*/cli/shells/fish`, `home/cli/editors/nvim`, `home/cli/terminals/ghostty` | `cli/{fish,nvim,ghostty}/` |
| `*/cli/tools/*` | `cli/tools/<feature>/` |
| `*/default` selectors, `home/cli/shells/zsh` | not ported: one of each, no selectors (see `cli/README.md`) |
| `*/desktops/*`, `*/styles/stylix` | `desktops/…`; stylix at `desktops/styles/stylix/` |
| `*/browsers/*`, `*/communication/*`, `*/media/*` (apps), `home/productivity/*`, `home/games/*` | `apps/<group>/<feature>/` |
| `home/development/*` | `development/<group>/<feature>/` |
| `*/services/*`, `home/virtualization/podman` | `services/<group>/<feature>/` |
| `home/virtualization/k8s` | `development/platforms/k8s/` |
| `nixos/cli/tools/nix-ld` | `system/nix-ld/` |
| `*/roles/*` (purpose: home-server, media-server, work, agent-host, …) | `roles/<role>/` |
| `nixos/users`, `darwin/users`, `home/user` | `users/user-factory.nix` + `users/<name>/` |
| `nixos/users/child-lockdown`, `home/roles/child`, `home/desktops/gnome/profiles/*` | `users/profiles/<profile>/` |
| `systems/<arch>/<host>`, `homes/<arch>/<user>@<host>` | `hosts/<host>/` |
| `lib/defaults` | `constants/` |
| `lib/*` (functions) | `lib/`, only when used |
| `infra/<stack>` (repo root) | `infra/<stack>/` |
| `packages/<name>` (repo root) | `_package.nix` inside the feature that uses it (rule 11) |
| `overlays/*` | `nix/nixpkgs.nix` |

## How to add

**A feature.** Create `<domain>/<group>/<feature>.nix` with a flake-parts module. Turn it into a directory once it needs a second file:

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

**A package.** Put the `callPackage` file at `<feature>/_package.nix`, and add to the feature's module:

```nix
{
  perSystem = { pkgs, ... }: { packages.<name> = pkgs.callPackage ./_package.nix { }; };
  flake.modules.homeManager.<feature> = { pkgs, ... }: {
    home.packages = [ (pkgs.callPackage ./_package.nix { }) ];
  };
}
```

**A constant.** Declare it in `constants/_options.nix` (with a type and a
description), and set it once in a `constants/*.nix` file. Read it as
`config.constants.…` anywhere. A feature applies it with `mkDefault`. A host
that must deviate overrides the real option, never the constant.

**A test.** Add an `evalTests.<name> = { expr = …; expected = …; };` entry
next to the code. `nix flake check` runs them all.
