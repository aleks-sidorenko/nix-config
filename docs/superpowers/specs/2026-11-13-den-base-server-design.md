# den rewrite: base, headless server and install-validating VMs

Date: 2026-11-13
Status: draft, awaiting approval
Tracking: #272 (to be updated to match this design)

## Intent

Start the config over on [den](https://den.denful.dev/), from an empty tree, so
the mistakes of `master` (snowfall-lib) and of the plain-dendritic rewrite
(#267) do not carry over. The first slice is the **base** every NixOS host
shares and a **headless server** with no feature aspects (no media, backups,
games), plus **VM hosts that prove the install** of each.

The owner's principles, in their words: fully aligned with den principles,
aspect oriented, DRY, cohesion of features and their code, DRY for settings
like username and hosts. Use the latest and most advanced features den provides.

## Goals

- A den-native skeleton that later features slot into without restructuring.
- `base` and `server` roles, a `server` host that builds, and VM hosts
  (`base-vm`, `server-vm`) that are installed and checked by an automated test.
- Every name and setting written once: hostnames, usernames and platforms only
  in `den.hosts`; per-host facts as typed host options; shared facts as
  `den.schema.conf` options; a feature's own details inside its aspect.
- New `AGENTS.md` and `CLAUDE.md` describing this config.

## Non-goals (this slice)

- Feature aspects: media stack, backups, minecraft, nginx, workbook (darwin),
  standalone homes, desktop anything. They come in later slices.
- Deploying `server` from the branch. Without the media stack it would drop
  services; this slice only has to build it.
- The interactive install rehearsal (installer ISO + `just bootstrap server-vm`
  on the workbook) and the bootstrap script rewrite. Next slice.
- `infra/*` (terranix stacks). It stays on `master` until a later slice; den's
  `terranix-demo` template is the reference when it moves.
- Byte-identical closures with `master`.

## Anti-goals

- Hand-rolled plumbing den already ships (host registry, user factory,
  home-manager wiring, builders).
- `enable` options that gate a whole aspect, `mkIf` on roles, `specialArgs`,
  `lib.${namespace}`, data in `lib/`.
- A central list that features must be added to (persistence paths, secrets,
  firewall ports). Features declare their own and a collector gathers them.
- Hardcoded `alexander`, `server`, `/persist` or a domain inside an aspect.
- Legacy den API: `provides` / `_` for new code, `den.ctx`, `den.lib.parametric`
  and the other deprecated lib functions, `den.base`.

## Constraints

- den tracks `main`; `flake.lock` pins it. Updates go through `just update` in
  their own PR, reading den's `whats-changed` page first.
- `server` is x86_64-linux. The workbook (aarch64-darwin) runs Linux guests only
  through the parked Linux builder.
- `master` keeps deploying while the branch is open.
- SOPS recipients in `.sops.yaml` and the `identities/` key material carry
  over unchanged; they are data, not design. Only `path_regex` rules change
  when files move.
- Repo conventions carry over: `nix develop` + `just`, recipe naming
  (`<group>-<verb>`), Conventional Commits, branch names `<type>/<desc>`, terse
  comments that explain why.

## Approaches

| Decision | Options considered | Chosen | Why |
|---|---|---|---|
| Starting point | Build on the dendritic branch (#272 as written) / start from an empty tree | **Empty tree** | Owner's call: avoid carrying over mistakes. Old code is reference only. |
| What a VM run proves | A: automated install test / B: interactive ISO + `just bootstrap` / C: both | **C** | A gates every change; B rehearses the real path occasionally, after the bootstrap rewrite. |
| How a VM gets its aspects | Declared by hand (role + hardware) / generated from the real host | **By hand** | Explicit, about two lines per VM; generation would hide the platform change. |
| Flake inputs | Hand-written `flake.nix` / flake-file | **flake-file** | Each aspect declares its own input next to its code (cohesion). |
| Aspect structure | Flat in `den.aspects` (drupol) / a namespace (den `example` template, quasigod) / nested in `den.aspects` with the aspect path mirroring the file path (den docs) | **Nested `den.aspects`, path mirrors file, no namespace** | Owner's call: flat names make navigation hard. Nesting already keeps features apart from host and user aspects, so a namespace would only add a concept. |

## Design

### Where it lives

A long-lived branch `refactor/den-aspects`, cut from `master`. Its first commit
deletes everything except: `identities/`, the SOPS files (moved to `secrets/`,
see below), `.sops.yaml`, `docs/superpowers/`, `LICENSE*`. `master` is merged in
regularly; changes there are ported by hand. The branch merges to `master` once
every in-scope host builds and deploys from it (a later slice).

### Mechanism map

Which den mechanism holds what. This table is the core of the design and goes
into `AGENTS.md`.

| Kind of thing | Mechanism | Example |
|---|---|---|
| A host, its platform, its users | `den.hosts.<system>.<host>.users.<user>` | `den.hosts.x86_64-linux.server.users.alexander = { };` |
| A fact about one host or user | typed option on `den.schema.host` / `den.schema.user`, declared next to the aspect that reads it | `host.stateVersion`, `user.identity` |
| A fact shared by all entities, overridable per entity | `den.schema.conf` option with a default, declared next to the aspect that reads it | `timeZone`, `locales` |
| A per-host tunable of one aspect | the [aspect settings](https://den.denful.dev/guides/aspect-settings/) pattern (`den.reservedKeys = [ "settings" ]`) | `host.settings.storage.disko.device` |
| Data many aspects contribute, one consumes | a [quirk](https://den.denful.dev/guides/quirks/) | `persist`, `persistHome` |
| A host's or user's own config | its entity aspect in `den.aspects`, created by den | `den.aspects.server`, `den.aspects.alexander` |
| A feature | `den.aspects.<category>.<feature>`, with every class it touches | `den.aspects.security.ssh` |
| A variant of one feature | a nested aspect under that feature | `den.aspects.services.tailscale.exit-node` |
| A role | a feature whose body is mostly `includes`, under `den.aspects.roles` | `den.aspects.roles.server` |
| Applies to every host / user | `den.schema.host.includes` / `den.schema.user.includes` / `den.default` | home-manager defaults |
| A flake input | `flake-file.inputs.<name>` in the aspect that uses it | disko input in the disko aspect |
| Relations between entities | den policies and batteries (`mutual-provider`, `user-aspects`) | |
| Flake outputs not built by den | flake-parts modules reading `den.hosts` | deploy-rs nodes, install-test checks |

Rules that follow from it:

- Including an aspect enables it. An aspect asks for `{ host }`, `{ user }` or
  `{ host, user }` and that alone decides where it applies.
- No settings module. A setting is declared by the aspect that reads it, so
  deleting the aspect deletes the setting.
- A feature that needs another's internals reads a quirk or a schema option,
  never a shared constants file.
- Aspects are named, not anonymous, in `includes` (den's own advice).

### Naming convention

Following den's own docs (`den.aspects.lang.go`, `den.aspects.editor.vscode`,
`den.aspects.roles.dev-gui` in the quirk recipes) and quasigod's category
nesting (`styx.apps.zsa`, `styx.virt.podman`), without a namespace:

1. **Top-level names in `den.aspects` are hosts, users and categories.** den
   creates one entity aspect per host and per user; their files are
   `modules/hosts/<host>/` and `modules/users/<user>.nix`. Every feature sits
   under a category, so it can never merge into a host's or user's own aspect.
   **A host or user is never named after a category** (`system`, `security`,
   `roles`, …), and vice versa.
2. **The aspect path mirrors the file path**:

   | Aspect | File |
   |---|---|
   | `den.aspects.<category>.<feature>` | `modules/<category>/<feature>.nix` |
   | same, when it has variants or helper files | `modules/<category>/<feature>/default.nix` |
   | `den.aspects.<category>.<feature>.<variant>` | `modules/<category>/<feature>/<variant>.nix` |

   Initial categories: `system`, `storage`, `security`, `services`,
   `hardware`, `roles`. New ones are added when a feature fits none of them.
   `hosts` and `users` are never categories; those directories belong to
   entity aspects.
3. **Roles are `den.aspects.roles.<name>`**: features that mostly include others.
4. **Category parents (`den.aspects.security`) hold nothing and are never included.**
   Variants nest under their feature, whose parent stands alone
   (`den.aspects.services.tailscale` and `den.aspects.services.tailscale.exit-node`). A nested
   aspect is not applied with its parent; it must be included.
5. **No `._` (include all children)**. Includes stay explicit, so adding a file
   never turns something on by itself.
6. **No path segment may be a den reserved key**, because den reads those keys
   inside any aspect as instructions, not as nested aspects:
   - structural: `name`, `description`, `meta`, `includes`, `excludes`,
     `admits`, `policyEnforcement`, `provides`, `policies`, `into`, `classes`,
     `_module`, `_`, anything starting with `__`, and our reserved `settings`;
   - class names: `nixos`, `darwin`, `homeManager`, `os`, `user`, `hjem`,
     `maid`, `wsl`, and any class we add;
   - quirk names: `persist`, `persistHome`, and any quirk we add.

   A CI check that walks `den.aspects` categories and fails on such a segment, or on an aspect
   whose path doesn't match its file, is worth having (builder's call how).
7. **No namespace.** Features are referenced as `den.aspects.<path>` (files take
   `{ den, ... }:`). Exporting them for other flakes (`den.namespace … true`)
   can be added later if it's ever needed.

Code style follows den's: `inherit` over `with`, `lib.optional*` for small
conditionals.

### Layout

```
flake.nix                    # generated by flake-file; never edited by hand
modules/
  den.nix                    # den, flake-file, import-tree inputs + flakeModules;
                             #   den.schema defaults, reservedKeys, migrations flag
  flake/                     # flake-level plumbing (flake-parts modules)
    formatter.nix  devshell.nix  deploy.nix  install-tests.nix  nh.nix
  _lib/settings-type.nix     # the aspect-settings generator from den's guide
  roles/
    base.nix                 # roles.base
    server.nix               # roles.server
  system/                    # system.nix, .locale, .boot, .networking, .headless
  storage/                   # storage.disko (layout), storage.impermanence (+ persist quirks)
  security/                  # security.sops, security.ssh, security.user-password
  services/                  # services.tailscale
  hardware/
    qemu-guest.nix           # hardware.qemu-guest
  users/
    alexander.nix            # den.aspects.alexander (entity aspect)
  hosts/
    server/                  # default.nix (entity + host aspect), _hardware.nix
    server-vm/default.nix
    base-vm/default.nix
secrets/                     # nixos.yaml (moved from modules/nixos/); .sops.yaml path_regex updated
identities/                  # unchanged
```

A host directory holds that host's entity declaration and its entity aspect,
so one host is one place. `den.nix`, `flake/` and `_lib/` are plumbing, not
aspect categories; everything else under `modules/` follows the path-mirroring
rule.

### Entities and wiring (`modules/den.nix`)

- Imports `inputs.den.flakeModules.dendritic` and flake-file's dendritic and
  auto-follow modules, as drupol's config does.
- `den.schema.user.classes = lib.mkDefault [ "homeManager" ];`
- `den.migrations.user-host-content.acknowledged = true;` so the 0.20 behaviour
  applies now. Hosts include `den.batteries.mutual-provider` explicitly through
  `den.schema.host.includes`.
- `den.schema.host.includes = [ den.batteries.hostname den.batteries.mutual-provider den.aspects.system.nix den.aspects.system.locale den.aspects.system.networking den.aspects.security.ssh ];`
  The universal aspects (see Roles) are attached here once, not listed by
  every host.
- `den.schema.user.includes = [ den.batteries.define-user ];`
- `den.reservedKeys = [ "settings" ];` and the settings generator from den's
  guide, imported into `den.schema.host`.
- `den.default` sets `home-manager.useGlobalPkgs` and `useUserPackages`.

Host options declared here because every host needs them:
`stateVersion` (no default, so every host must set it; feeds both
`system.stateVersion` and its users' `home.stateVersion`).

### Roles

A role is a feature under `den.aspects.roles` that mostly includes others. Layers attach in two
ways:

- **Universal**: on every host (NixOS, later darwin and the installer), through
  `den.schema.host.includes`. `os`-class content reaches NixOS and darwin;
  `nixos`-only content is ignored on darwin.
  - `den.aspects.system.nix`: nix settings, gc, flakes, trusted users from the host's users.
  - `den.aspects.system.locale`: reads `timeZone`, `locales`, `layouts` from `den.schema.conf`
    options it declares (defaults: `Europe/Kyiv`, the current locales).
  - `den.aspects.system.networking`: firewall on; the hostname comes from the battery.
  - `den.aspects.security.ssh`: sshd hardened, host keys; emits
    `persist.files = [ "/etc/ssh/ssh_host_ed25519_key" … ]`. Authorized keys
    come from each user's identity.
- **Roles**: included explicitly by hosts that need them.

`den.aspects.roles.base`: what an *installed* NixOS host adds to the universal layer. The
future installer ISO gets the universal layer and not this.

- `den.aspects.system.boot`: systemd-boot, systemd initrd.
- `den.aspects.storage.disko`: the btrfs layout with root (blank snapshot), nix, log, swap,
  persist, home and data subvolumes, 1G ESP. Aspect settings: `device`,
  `swapSize` (default 8G), `encrypted` (LUKS, default `true` for new hosts).
  **`server` must match the disk already installed on it** (master's
  `systems/x86_64-linux/server/disks.nix`: unencrypted, same subvolume names,
  mount options and swap), because a later deploy from the branch must not
  change the live disk's shape. `server` sets `encrypted = false`. A parity
  check compares `server`'s evaluated `disko.devices` and `fileSystems` with
  master's (as the dendritic branch did with `_disko-master.json`).
- `den.aspects.storage.impermanence`: blank-snapshot rollback of root in initrd, and the
  collector that turns the `persist` / `persistHome` quirks into
  `environment.persistence` / `home.persistence`. The persistence root is its
  own aspect setting (default `/persist`).
- `den.aspects.security.sops`: sops-nix with `defaultSopsFile = secrets/nixos.yaml`, the
  file shared by every NixOS host today. It is moved, not re-encrypted (see
  Secrets). The age key path depends on whether the host is
  impermanent; the impermanence aspect sets it (it created the problem), so
  sops never reads an impermanence setting.
- The user aspect, through the host's users: see Users.

`den.aspects.roles.server` = `den.aspects.roles.base` + `den.aspects.system.headless` (no docs, no fonts/X, watchdog,
`srvos`-style hardening where it fits) + `den.aspects.services.tailscale` (auth key from SOPS,
emits `persist.directories = [ "/var/lib/tailscale" ]`).

Feature aspects later attach to `den.aspects.roles.server` or to a new role
(`den.aspects.roles.home-server`) without changing `den.aspects.roles.base`.

### Users

- `den.aspects.alexander.includes = [ den.batteries.primary-user (den.batteries.user-shell "fish") ];`
- `den.schema.user` options, declared next to the aspects reading them:
  - `identity` (default `user.userName`): which `identities/<name>/` folder
    holds the user's SSH and GPG public keys.
  - The password secret name is derived, not declared:
    `user-${user.userName}-password`, set as `hashedPasswordFile` by a
    `den.aspects.security.user-password` aspect in `den.schema.user.includes`.
- Home-manager on servers is minimal: the user's shell and `home.stateVersion`.

### Hosts

```nix
# modules/hosts/server/default.nix
den.hosts.x86_64-linux.server = {
  users.alexander = { };
  stateVersion = "26.05";
  settings.storage.disko = {
    device = "/dev/disk/by-id/ata-SSD_2TB_004208";
    encrypted = false;
  };
  deploy.sshUser = "alexander";
};
den.aspects.server = {
  includes = [ den.aspects.roles.server ];
  nixos.imports = [ ./_hardware.nix ];
};

# modules/hosts/server-vm/default.nix
den.hosts.x86_64-linux.server-vm = {
  users.alexander = { };
  stateVersion = "26.05";
  settings.storage.disko = {
    device = "/dev/vda";
    encrypted = false;
  };
};
den.aspects.server-vm.includes = [ den.aspects.roles.server den.aspects.hardware.qemu-guest ];
```

`base-vm` is the same with `den.aspects.roles.base`. `den.aspects.hardware.qemu-guest` holds the
virtio/qemu-guest profile and any VM-only setting (smaller swap).

`server-vm` mirrors `server`'s disk, so it is unencrypted (`encrypted = false`)
and its install test proves `server`'s real layout. `base-vm` keeps the default
(`encrypted = true`), so its test covers the LUKS path new hosts get.

VM hosts are x86_64-linux in this slice, so the install test runs on the same
platform as `server`, in CI on KVM runners. An aarch64 variant for the
workbook comes with the interactive rehearsal, if it's needed then.

### Install test

A flake-parts module (`modules/flake/install-tests.nix`) adds a check
`install-<host>` for every host where
`host.hasAspect den.aspects.hardware.qemu-guest`, on that host's system. It uses
disko's install test machinery against the host's real config:

1. Partition and format the virtual disks with the host's disko layout, LUKS
   included (test passphrase), install, boot.
2. Secrets: a throwaway age key and a secrets file encrypted to it are built at
   test time. The secret names come from the host's own `sops.secrets`, so
   adding a secret to an aspect never requires touching the test. Values that
   need a format (password hashes) are generated to match.
3. Assert: `multi-user.target`, `sshd` active, the primary user exists and its
   password secret decrypted, every quirk-collected persist path is a bind
   mount, a file written to `/` is gone after a power cycle and one written to
   the persistence root survives.
4. Role-specific asserts come from the roles: `den.aspects.roles.server` adds
   `tailscaled` active (autoconnect disabled in the test, no network). How a
   role contributes asserts (a `install-checks` quirk is the natural fit) is
   the builder's call.

**Install tests run in CI only** (owner's call). The workbook can't run x86_64
NixOS VMs, and no remote builder is set up for it. CI runs every
`install-<host>` check on an x86_64 KVM runner for each push and PR, and that
result is the gate before a deploy. On the workbook, `just check` evaluates
everything (including the test derivations) without building the tests.
`just vm-test <host>` builds one test and works on any x86_64 Linux machine
with KVM. On darwin it says the tests run in CI and exits non-zero.

### Secrets

- `modules/nixos/secrets.yaml` moves to `secrets/nixos.yaml` with `git mv`, and
  its `.sops.yaml` rule's `path_regex` is updated to the new path. Recipients
  don't change, so no decryption or owner key is needed.
- Per-host secrets files are not part of this slice. Splitting needs the owner's
  key and a decision on which values are shared; it can come later as its own
  change.
- `base-vm` and `server-vm` build against the same `secrets/nixos.yaml` (sops-nix
  only checks the file exists at build time). They never decrypt it: the install
  test replaces it with test secrets. Real recipients for VMs come with the
  interactive rehearsal.
- Home, darwin and infra secrets files stay on `master` until their slices.

### Deploy

`modules/flake/deploy.nix` builds `flake.deploy.nodes` and the deploy-rs checks
in one place from every NixOS host with a `deploy` option set (declared there:
`hostname` default `host.name`, `sshUser`). Only `server` sets it. Building the
attrset in one place avoids the `flake` class's one-level merge.

### Flake inputs (flake-file)

Each aspect declares the inputs it uses (`flake-file.inputs.disko`,
`.impermanence`, `.sops-nix`, `.home-manager`, `.deploy-rs`, `.srvos` if used).
`nix run .#write-flake` regenerates `flake.nix`; it's wrapped as
`just flake-write`, and `just check` fails if `flake.nix` is stale.
nixpkgs channel: `nixos-26.05`, with `nixpkgs-unstable` as `pkgs.unstable`
through den's nixpkgs guide pattern, declared in one aspect.

### Tooling

New `justfile` with only what this slice exercises, following the existing
naming scheme: `format`, `format-check`, `lint`, `lint-fix`, `check`,
`flake-check`, `flake-write`, `build <host>`, `vm-test <host>`, `update`.
`deploy` arrives when a host deploys from the branch. CI: one workflow on
x86_64 KVM runners, running `just check` (format, lint, stale-flake, eval) and
then building every `install-<host>` check.

### AGENTS.md and CLAUDE.md

`CLAUDE.md` is one line, `@AGENTS.md`. `AGENTS.md` covers:

- Overview and the four den concepts (entities, aspects, policies, quirks), in
  den's terms, linking den's docs rather than restating them.
- The mechanism map and naming convention above, as the rule for where
  anything goes and what it's called.
- How to add a feature, a host, a VM host, a user, a setting, a quirk, an input.
- Anti-goals as rules (from this doc).
- den code style (from den's `AGENTS.md`): `inherit` over `with`, comments say
  why, stage new files before evaluating.
- Repo conventions carried over from the current `AGENTS.md`: `nix develop` +
  `just`, recipe naming, secrets handling, Conventional Commits, branch names.
- Commands: the `just` recipes, `vm-test`, updating den.

## Acceptance (this slice)

- `just check` passes: format, lint, `flake.nix` up to date, flake eval.
- `nixosConfigurations.server` builds.
- `install-base-vm` and `install-server-vm` pass in CI.
- `server`'s disk parity check against master's layout passes.
- No hostname, username, `/persist` path or domain appears in an aspect. A
  review of `modules/` outside `modules/hosts/`, entity declarations and option
  defaults finds none (aspect names like `den.aspects.roles.server` don't count).
- Top-level names in `den.aspects` are only hosts, users and categories; every
  feature and role sits under a category whose path mirrors its file.
- No legacy den API, no `enable`-gated aspects, no `with`.
- `AGENTS.md` lets a new contributor add a feature aspect without reading this
  doc.

## Left to the builder

- Exact nix settings, server hardening choices, and whether `srvos` is used.
- File split inside each directory.
- How role-specific test asserts are contributed.
- The disko test harness details (LUKS passphrase handling, power-cycle).
- Whether eval-level unit tests (nix-unit / den's `denTest` style) are worth
  adding beyond the install tests.
