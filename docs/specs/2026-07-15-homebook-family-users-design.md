# Design: `homebook` host + reusable multi-user / family model

- **Date**: 2026-07-15
- **Status**: Approved; spec-review complete (3 blockers + should-fixes folded in)
- **Scope**: Add a new shared-laptop host `homebook`, introduce a reusable
  multi-user ("family member") abstraction on NixOS, and add an 8-year-old
  child account (`dima`) restricted to Minecraft with no browser access.

## 1. Goals

1. Add a new host `homebook`, structured like existing hosts and composed via a
   role (`homebook`) that sets up other roles — analogous to `desktop` but
   **without** the `development` sub-role.
2. Introduce a **reusable, extensible** way to declare multiple users
   (family members) on a host, usable by any host, not just `homebook`.
3. Declare **every** user — including the primary (`alexander`) — through the
   same mechanism. The primary is not a separate concept; it is just a flagged
   entry.
4. On `homebook`, add a child account `dima` (age 8): Minecraft available, no
   browser, no admin.
5. Disk encryption is **off** for `homebook`.

## 2. Non-goals

- No changes to the darwin (`workbook`) or home-manager per-context `user`
  modules. Multi-user is a NixOS (Linux, shared-machine) concern.
- No parental-control time limits / content filtering beyond "no browser + no
  sudo". (YAGNI — can be layered later.)
- No real hardware/disk values for `homebook` yet; scaffolded with `TODO`
  placeholders to be filled from the physical machine.

## 3. Background — current state

- **Hosts**: `systems/<arch>/<hostname>/default.nix` enable roles (e.g. the
  `desktop` host sets `nix-config.roles.desktop = enabled`).
- **NixOS roles** (`modules/nixos/roles/`) compose other roles + system config.
  The nixos `desktop` role enables `common` + `gaming` + `backup` + GNOME.
  `development` is **not** a nixos role.
- **Home roles** (`modules/home/roles/`): `development` lives here and is
  enabled by the home `desktop` role.
- **User module** (`modules/nixos/user/default.nix`): single-user only. It
  creates exactly one `users.users.${cfg.name}` from `nix-config.user.name`,
  wires the SOPS password `user-<name>-password`, sets shell/home/groups, and
  sets `home-manager.useGlobalPkgs`/`useUserPackages`.
- **Home discovery**: snowfall-lib auto-imports `homes/<arch>/<user>@<host>/`
  and wires each into the matching host's home-manager.
- **`nix-config.user` (singular)** is referenced as "the primary/admin user".
  **Readers**: `lib/context` (twice — `userName`/`homeConfig`), `lib/deploy`,
  nixos+darwin `ssh` (`authorizedKeys`), `doas`, `greetd` autologin, home
  `ssh`/`fish`, and `services/media/qbittorrent` (indirectly via
  `lib.${namespace}.userName config`). **Writers** (do
  `nix-config.user.extraGroups = [...]`, which the alias must accept as a
  mergeable option): `podman`, `virtualbox`, `kvm`, and the nixos `desktop` role
  (`audio`/`sound`/`video`). The `homebook` nixos role must likewise contribute
  those desktop groups to the primary.
- **Disks**: the custom `nix-config.disks.disko` abstraction has a per-disk
  `encrypted` flag (default `false`); `false` routes to a plain BTRFS partition
  (`mkBtrfsPartition`), `true` wraps it in LUKS. No module change needed for an
  unencrypted host.
- **Secrets**: `modules/nixos/secrets.yaml` currently holds
  `user-alexander-password`.

## 4. Design

### 4.1 Unified users module — `modules/nixos/users/` (new)

Single declaration surface and **single source of account creation** for all
users on a host:

```nix
nix-config.users = {
  alexander = { primary = true; admin = true; };  # profile defaults "adult"
  dima       = { profile = "child"; };            # admin defaults false
};
```

**Per-entry options** (`nix-config.users.<name>`):

| Option               | Type            | Default   | Meaning                                             |
| -------------------- | --------------- | --------- | --------------------------------------------------- |
| `primary`            | `bool`          | `false`   | Marks the primary/admin user (exactly one required) |
| `admin`              | `bool`          | `false`   | Adds `wheel` (sudo)                                  |
| `profile`            | `"adult"\|"child"` | `"adult"` | Group/permission preset                          |
| `extraGroups`        | `listOf str`    | `[]`      | Additional groups                                   |
| `extraOptions`       | `attrs`         | `{}`      | Passed through to `users.users.<name>`              |
| `initialPassword`    | `nullOr str`    | `null`    | Fallback password if SOPS disabled                  |
| `hashedPasswordFile` | `nullOr str`    | `null`    | Explicit hashed-password file override              |

**Behavior**:

- A shared `mkUser` helper is mapped over `nix-config.users` to generate one
  `users.users.<name>` per entry — this is the **only** place accounts are
  created (no duplication).
- For each user it wires `sops.secrets."user-<name>-password"`
  (`neededForUsers = true`, `sopsFile = ../secrets.yaml`) when SOPS is enabled,
  sets the default shell, `home = "/home/<name>"`, `group = "users"`,
  `isNormalUser = true`.
- **Group presets**:
  - Base groups for everyone: `networkmanager`, `input`, `tty`.
  - `admin = true` adds `wheel`.
  - `profile = "adult"` adds nothing extra beyond base (desktop groups such as
    `audio`/`video` continue to come from the desktop/gaming roles as today).
  - `profile = "child"` adds `audio`, `video`, `input` (needed for games) and
    **never** `wheel`. An assertion fails if a `child` entry also sets
    `admin = true`.
- `sops.secrets` for each user password + `home-manager.useGlobalPkgs = true` /
  `useUserPackages = true` (moved here from the old module) are set once.
- **Default**: `nix-config.users` defaults to
  `{ ${defaults.user} = { primary = true; admin = true; }; }` (i.e. `alexander`
  primary/admin). This keeps every existing host that declares nothing
  (`desktop`, `server`, `vm` via the `common` role) working unchanged and
  satisfies the assertion below. A host that declares its own `nix-config.users`
  (e.g. `homebook`, `install-iso`) replaces the default and must therefore
  declare its primary explicitly.
- **Assertion**: exactly one entry has `primary = true`.

**Source-of-truth / recursion guardrail** (one-directional, mandatory):
`nix-config.users` (plural) is the sole source of truth. The singular
`nix-config.user.name` derives *from* the plural primary entry. The plural
option's default MUST be a literal (`defaults.user`), and MUST NOT be computed
from `config.nix-config.user.*` — deriving the plural default from the singular
while deriving the singular from the plural is an infinite recursion. Reading
`config.nix-config.user.extraGroups` inside the same module to fold into the
primary account is safe (a module reading its own `config.*` is not recursive;
the current module already does `cfg = config.${namespace}.user`).

**Backward-compat alias** (defined *inside the same `users` module*): the legacy
singular `nix-config.user` surface is retained **only** as a derived view of the
primary, so the ~15 existing references and the group-injecting modules keep
working unchanged:

- `nix-config.user.name` is derived from the `primary = true` entry via
  `mkDefault` (NOT `readOnly`), so a host may still override it directly if ever
  needed without an eval conflict.
- `nix-config.user.extraGroups` stays a real, mergeable option — modules like
  `podman`/`virtualbox`/`kvm` keep doing `nix-config.user.extraGroups = [...]`;
  the `users` module folds those groups into the **primary** account.
- `nix-config.user.initialPassword` / `hashedPasswordFile` / `extraOptions`, if
  set, apply to the primary account.

**Removal of the old module**: `modules/nixos/user/default.nix` is deleted. Its
account-creation logic, SOPS wiring, and `home-manager.*` settings are absorbed
into `modules/nixos/users/`. There is exactly one `users.users.*`
account-creation path afterwards.

Net effect: hosts declare everyone in `nix-config.users`; existing call sites
and modules referencing `nix-config.user.*` compile and behave as before via the
derived alias; there is a single source of truth and zero duplication.

**Migration of existing hosts** (regression scope — all NixOS configs are
re-evaluated by `nix flake check`):

- `desktop`, `server`, `vm`: **no change** — they declare nothing and inherit
  the default `nix-config.users` (alexander primary/admin). The `common` role's
  now-redundant `nix-config.user.enable = true`
  (`modules/nixos/roles/common/default.nix`) is removed; account creation is
  driven solely by `nix-config.users`.
- `install-iso` (`systems/x86_64-install-iso/minimal/default.nix`): **must be
  migrated**. It currently sets its base options inline and
  `nix-config.user = { name = "nixos"; ... }` directly (no `common`). Convert to
  the new `minimal` role (4.1b) plus:
  ```nix
  nix-config.roles.minimal = enabled;
  nix-config.users.nixos = { primary = true; admin = true; initialPassword = "nixos"; };
  ```
  SOPS is disabled on the ISO, so the `initialPassword` path must be honored when
  no SOPS secret exists (as the current module already does). Full flow in 4.6b.
- `workbook` (darwin) and all `homes/*` are unaffected — they use the separate
  darwin/home `user` modules in their own evaluations (see Non-goals).

### 4.1b `minimal` role + `common` refactor

Extract the bare live/installer base into a reusable role so the install-iso is
role-driven like every other host, and `common` reuses it instead of
duplicating the base.

- **`modules/nixos/roles/minimal/` (new)**: `nix-config.roles.minimal.enable`.
  Enables only the bare base:
  ```nix
  nix-config = {
    security.ssh.enable = true;
    system = { nix.enable = true; locale.enable = true; networking.enable = true; };
    cli.shells.fish = { enable = true; default = true; };
  };
  ```
- **`modules/nixos/roles/common/` (refactor)**: `common` now enables
  `roles.minimal = enabled` and adds only the persistent-system pieces on top:
  `security.sops`, `system.boot`, `system.fs`, `system.nix.githubAuth`,
  `disks.impermanence`. The redundant `nix-config.user.enable = true` is dropped
  (account creation is driven by `nix-config.users`; see 4.1). The **effective**
  configuration of `desktop`/`server`/`vm` is unchanged — validated by
  rebuilding their toplevels.
  - Note: `minimal` sets `system.nix.enable = true`; `common` additionally sets
    `system.nix.githubAuth = true` — these merge under `system.nix`.

### 4.2 `homebook` role pair

Mirrors how `desktop` exists as both a nixos and a home role.

Both roles **reuse `desktop`** rather than duplicating it (DRY), since a homebook
is a desktop-class laptop that differs only by dropping `development` and adding
laptop power management.

- **`modules/nixos/roles/homebook/` (new)**: `nix-config.roles.homebook.enable`
  → enables `roles.desktop = enabled` (which pulls in `common`, `gaming`,
  `backup`, GNOME, virtualisation, desktop user groups) **plus** laptop power
  management via `services.power-profiles-daemon.enable = true` (stock NixOS,
  GNOME-compatible; not `tlp`, which would conflict). No `development` on the
  nixos side anyway.
- **`modules/home/roles/homebook/` (new)**: `nix-config.roles.homebook.enable`
  → enables `roles.desktop = enabled` and turns **off** development:
  `roles.development.enable = false`. For this override to not conflict, the home
  `desktop` role's `roles.development.enable` is changed from a plain `true` to
  `mkDefault true` (a one-token change; desktop hosts still get development since
  nothing else overrides it). This reuses the entire desktop home composition
  with a single delta instead of copy-pasting ~40 lines.

### 4.3 `child` role — `modules/home/roles/child/` (new)

Minimal, restricted home role, reusing existing game modules:

```nix
config = mkIf cfg.enable {
  nix-config = {
    roles.common = enabled;      # base user env (shell, editor, terminal, etc.)
    games.minecraft = enabled;   # reuse existing module -> prismlauncher
  };
};
```

- Reuses `nix-config.games.minecraft` (`modules/home/games/minecraft/`), which
  installs **Prism Launcher** (offline-capable, no Microsoft account required).
- **No** `browsers`, `development`, `communication`, `media`, `router-manager`.
- The GNOME session is provided by the host (nixos `homebook` role); the child
  only gets `common` + Minecraft.
- Enforcement of "no browser": the child account has no `wheel` (from
  `profile = "child"`), so `dima` cannot install a browser system-wide, and no
  browser is present in the child's home closure.

### 4.4 Host — `systems/x86_64-linux/homebook/`

- **`default.nix`**:
  ```nix
  nix-config = {
    roles.homebook = enabled;
    users = {
      alexander = { primary = true; admin = true; };
      dima       = { profile = "child"; };
    };
    styles.stylix.wallpaper = "<pick>";
  };
  system.stateVersion = "25.05";
  nixpkgs.config.allowUnfree = true;  # if needed for GNOME/media
  ```
- **`hardware.nix`**: placeholder mirroring `desktop`, marked with `TODO` to
  replace from the real machine's `nixos-generate-config`.
- **`disks.nix`**: BTRFS + impermanence, **`encrypted = false`** on each disk
  (no LUKS), `TODO` for real `device` by-id paths. Structure mirrors
  `desktop/disks.nix`. **Impermanence is mandatory here**, not optional: the
  `homebook` role composes `common`, which enables
  `disks.impermanence.enable = true` (root `@root` is wiped to a blank snapshot
  on every boot). Therefore `disks.nix` MUST provide:
  - a disk **named `root`** carrying the `@root` subvolume with
    `createBlankSnapshot = true` (the impermanence wipe service mounts
    `by-label/root` = `defaults.disks.root`; a different name breaks rollback),
    plus `swap`, `nix`, and `log` (`neededForBoot`) subvolumes;
  - a **`persist`** subvolume (`neededForBoot`, mounts at `/persist` =
    `defaults.persistence.root`) and a **`home`** subvolume — without these, all
    persisted and home data is lost on reboot. These may live on the same disk
    or a second data disk (single-disk laptop is fine).

### 4.5 Homes (snowfall auto-discovered)

- **`homes/x86_64-linux/alexander@homebook/default.nix`**:
  `nix-config.roles.homebook = enabled;` + `nix-config.user.enable = true;` +
  stateVersion (no monitor block — laptop uses internal display / kanshi
  defaults; refine later).
- **`homes/x86_64-linux/dima@homebook/default.nix`**:
  `nix-config.roles.child = enabled;` + `nix-config.user.enable = true;` +
  stateVersion.

### 4.6b install-iso migration + build documentation

The `install-iso` (`minimal`) host is migrated to the unified model (see 4.1
migration list) **and** its build/usage flow is documented in the tracked docs
(README + `docs/bootstrap.md`), which currently only carry a one-line build
command and no flashing/usage instructions.

- **Code**: `systems/x86_64-install-iso/minimal/default.nix` becomes
  role-driven, matching every other host. Replace the inline base options
  (`security.ssh`, `system.{locale,networking,nix}`, `cli.shells.fish`) with
  `nix-config.roles.minimal = enabled` (see 4.1b), and replace the direct
  `nix-config.user = { name = "nixos"; ... }` with
  `nix-config.users.nixos = { primary = true; admin = true; initialPassword = "nixos"; }`.
  Keep the ISO-specific bits (`isoImage`, `system.stateVersion`). SOPS stays
  disabled on the ISO, so the account is created with the plaintext
  `initialPassword` (the `mkUser` helper must apply `initialPassword` when no
  SOPS secret exists, matching current behavior).
- **Docs** (tracked): document the full flow, not just the build command:
  1. Build: `nix build .#install-isoConfigurations.minimal` → the image is at
     `./result/iso/nixos-minimal-*.iso` (from `isoImage.isoName = "nixos-minimal"`).
  2. Flash to USB: `sudo dd if=./result/iso/nixos-minimal-*.iso of=/dev/sdX
     bs=4M status=progress conv=fsync` (identify `/dev/sdX` with `lsblk`).
  3. Boot the target from USB; log in as `nixos` / `nixos` (the credentials
     declared above). The ISO enables SSH, fish, networking, and locale.
  4. Proceed with the bootstrap/deploy flow (link to the existing
     `docs/bootstrap.md` bootstrap section).
  - README's "Build Installer ISO" section gains a pointer to the fuller
    walkthrough; the walkthrough itself lives in `docs/bootstrap.md`.

### 4.6 Secrets

- Add `user-dima-password` to `modules/nixos/secrets.yaml`
  (`just secrets-edit nixos`). The creation rule in `.sops.yaml` is file-level
  (`path_regex`), so adding this secret key needs **no** `.sops.yaml` change.
- **Mandatory** (not conditional): `modules/nixos/secrets.yaml` is currently
  encrypted only to the `desktop` and `server` host age keys. Because both
  `homebook` accounts use `neededForUsers = true`, the **host itself** must
  decrypt `user-alexander-password` and `user-dima-password` at boot using its
  SSH-host-key-derived age key. So `homebook`'s host key MUST be added to the
  `&hosts` anchor and the `modules/nixos/secrets.yaml` creation rule's `age:`
  recipients in `.sops.yaml`, followed by
  `sops updatekeys modules/nixos/secrets.yaml`. This depends on the `homebook`
  host key existing (produced during bootstrap), so like the placeholder
  hardware it is completed at bootstrap time, not during initial scaffolding.

## 5. Affected / new files

**New**:

- `modules/nixos/users/default.nix`
- `modules/nixos/roles/minimal/default.nix`
- `modules/nixos/roles/homebook/default.nix`
- `modules/home/roles/homebook/default.nix`
- `modules/home/roles/child/default.nix`
- `systems/x86_64-linux/homebook/{default.nix,hardware.nix,disks.nix}`
- `homes/x86_64-linux/alexander@homebook/default.nix`
- `homes/x86_64-linux/dima@homebook/default.nix`

**Modified**:

- `modules/nixos/secrets.yaml` (add `user-dima-password`)
- `.sops.yaml` (add `homebook` host key as a recipient — at bootstrap time)
- `modules/nixos/roles/common/default.nix` (extend `minimal`; move base options
  into `minimal`; drop redundant `nix-config.user.enable = true`)
- `systems/x86_64-install-iso/minimal/default.nix` (migrate
  `nix-config.user` → `nix-config.users.nixos`)
- `README.md` (expand "Build Installer ISO" to point at the walkthrough)
- `docs/bootstrap.md` (new "Build & use the installer ISO" walkthrough:
  build → flash → boot → login → bootstrap)

**Removed**:

- `modules/nixos/user/default.nix` (logic absorbed into `modules/nixos/users/`)

**Unchanged but relied upon** (via the derived `nix-config.user` alias): `doas`,
`greetd`, nixos/darwin `ssh`, `podman`, `virtualbox`, `kvm`, `lib/context`,
`lib/deploy`, home `ssh`/`fish`.

## 6. Testing / validation

- `just format` then `just check` (format-check + statix + deadnix).
- `nix flake check` / `just flake-check` — evaluates all configs incl. the new
  host and homes.
- Build the host toplevel without switching:
  `nix build .#nixosConfigurations.homebook.config.system.build.toplevel`.
- Verify existing configs still evaluate (regression from the `user` -> `users`
  refactor): build `desktop`, `server`, `vm` toplevels **and**
  `nix build .#install-isoConfigurations.minimal`; confirm `nix-config.user.name`
  still resolves to `alexander` on the regular hosts (and `nixos` on the ISO),
  and that podman/virtualbox/desktop-role group injection still lands on the
  primary.
- Confirm `homebook` disks.nix provides `persist`/`home` subvolumes and a
  `root`-labelled disk so impermanence rollback works.
- Confirm the `common` → `minimal` extraction is behavior-preserving: diff the
  evaluated option set (or rebuilt toplevel) of `desktop`/`server`/`vm` before
  vs after, and confirm the ISO still enables ssh/nix/locale/networking/fish via
  `roles.minimal`.
- Confirm `dima` has no `wheel` group and Prism Launcher is in dima's home
  closure while no browser package is.

## 7. Risks / mitigations

- **Refactor regressions**: the `user` -> `users` change touches a widely
  referenced option. Mitigation: keep the derived `nix-config.user` alias with
  identical semantics; validate by building all existing host toplevels before
  and after.
- **Exactly-one-primary invariant**: enforced by assertion so a
  mis-declared host fails fast at eval time.
- **Placeholder hardware/disks**: `homebook` is not bootstrap-ready until the
  real `device` ids and hardware are filled in; TODOs mark every placeholder.
```
