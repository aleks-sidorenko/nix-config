# den rewrite: base, headless server and install-validating VMs — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A from-scratch den config on branch `refactor/den-aspects` with a universal layer, `roles.base`, `roles.server`, a buildable `server` host, and `base-vm` / `server-vm` hosts whose install is proven by an automated test in CI.

**Architecture:** flake-parts + import-tree + den + flake-file. Hosts and users are den entities; features are nested `den.aspects.<category>.<feature>` whose path mirrors `modules/<category>/<feature>.nix`. Per-host facts are host options, shared facts `den.schema.conf` options, per-host aspect tunables use the aspect-settings pattern, persistence paths are quirks. Flake-level outputs den doesn't build (eval tests, install tests, deploy nodes) are flake-parts modules under `modules/flake/`.

**Tech Stack:** Nix flakes, flake-parts, import-tree, den (`github:denful/den`, tracked on `main`, pinned by `flake.lock`), flake-file (`github:denful/flake-file`), nixpkgs `nixos-26.05` (+ `nixos-unstable` as `pkgs.unstable`), home-manager `release-26.05`, disko, impermanence, sops-nix, deploy-rs, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-13-den-base-server-design.md` (read it first; this plan argues from it).

**Reference material (read, never copy wholesale):**
- den source and docs: `~/Projects/misc/nix-config/den/denful/den` (`docs/src/content/docs/guides/{aspect-settings,quirks,quirk-recipes,nixpkgs,home-manager}.mdx`, `reference/{batteries,schema}.mdx`, `templates/{default,example}`).
- flake-file: `github:denful/flake-file` (`modules/write-flake.nix` gives the `write-flake` app and `checks.check-flake-file`).
- drupol's den config: `~/Projects/misc/nix-config/den/drupol/infra` (`modules/dendritic.nix`, `modules/flake-parts/deploy.nix`).
- `master`: `systems/x86_64-linux/server/disks.nix`, `modules/nixos/disks/{disko,impermanence}/default.nix` (exact disk shape and rollback script).
- Prior rewrite: `git show origin/refactor/dendritic-server-media:<path>` for `modules/hosts/server/install-test.nix`, `modules/hosts/server/_parity.nix`, `modules/nix/eval-tests.nix`, `modules/security/ssh.nix`, `modules/services/networking/tailscale.nix`.

## Global Constraints

- Branch `refactor/den-aspects`, cut from `master`; never commit to `master`.
- Naming: `den.aspects` top level holds only hosts, users and categories. Feature `den.aspects.<category>.<feature>` ↔ `modules/<category>/<feature>.nix` (or `<feature>/default.nix` when it has variants or helpers); variant `…<feature>.<variant>` ↔ `modules/<category>/<feature>/<variant>.nix`. Categories: `system`, `storage`, `security`, `services`, `hardware`, `roles`. Hosts/users never named after a category.
- No path segment may be a den reserved key: `name description meta includes excludes admits policyEnforcement provides policies into classes _module _`, anything `__*`, `settings`, any class (`nixos darwin homeManager os user hjem maid wsl`), any quirk (`persist persistHome installChecks`).
- Category parents hold nothing and are never included. No `._`. No namespace. Named aspects in `includes`.
- No `enable`-gated aspects, no `mkIf` on roles, no `specialArgs`, no `with`, no legacy den API (`provides`/`_` except the cross-entity keys, `den.ctx`, `den.lib.parametric`, `den.base`).
- No hostname, username, `/persist` or domain literal inside a feature aspect; only in `modules/hosts/`, `modules/users/`, entity declarations and option defaults.
- Every flake input is declared with `flake-file.inputs.<name>` in the module that uses it; `flake.nix` is generated (`just flake-write`), never hand-edited after Task 1.
- `stateVersion = "26.05"` on every host in this slice.
- Shared defaults: `timeZone = "Europe/Kyiv"`, `locales = [ "en_US.UTF-8" "uk_UA.UTF-8" "ru_RU.UTF-8" ]`, `layouts = [ "us" "ua" "ru" ]`.
- Persistence root default `/persist`.
- `server`'s disk must match master's evaluated `disko.devices` and `fileSystems` exactly (parity check).
- Secrets: one file `secrets/nixos.yaml` (moved, never re-encrypted); recipients in `.sops.yaml` unchanged.
- Install tests run in CI only (x86_64 KVM). On darwin, `just check` evaluates everything without building them.
- Commits: Conventional Commits; comments terse and explain why; format with `just format` before each commit.

## Review Focus

1. **A deploy from the branch would reshape `server`'s live disk.** Expect: the parity checks fail on any difference in subvolume names, mount options, labels, swap or encryption. Pinned in Task 3.
2. **An aspect gains a secret and the install test silently stops covering it** (or fails on a missing dummy). Expect: test secrets are generated from the host's own `sops.secrets`, so every declared secret exists in the VM. Pinned in Task 5.
3. **Secrets fail on the second boot**, when root has been rolled back and sops reads its key before impermanence restores `/etc/ssh`. Expect: the user password secret exists after the power cycle. Pinned in Task 5.
4. **An aspect path segment collides with a den reserved key and is silently read as class/quirk content.** Expect: a naming check fails with the offending path. Pinned in Task 8.
5. **An input is added in an aspect but `flake.nix` isn't regenerated.** Expect: `check-flake-file` fails in `just check`. Pinned in Task 1.

---

### Task 1: Empty branch and den skeleton

**Files:**
- Delete: everything tracked except `identities/`, `modules/nixos/secrets.yaml`, `.sops.yaml`, `docs/superpowers/`, `LICENSE`, `LICENSE.md`
- Create: `flake.nix` (bootstrap, then generated), `modules/den.nix`, `modules/flake/{formatter,devshell,eval-tests}.nix`, `justfile`, `.gitignore`
- Commit the approved spec and this plan in the first commit.

**Interfaces:**
- Produces: option `evalTests.<name> = { expr; expected; }` (flake-parts level) collected into `checks.<system>.eval-tests`, failing with a list of `name: expected X, got Y`. Recipes: `format`, `format-check`, `lint`, `lint-fix`, `check`, `flake-check`, `flake-write`, `update`.

- [ ] **Step 1: Branch and empty the tree**

```bash
git switch -c refactor/den-aspects master
git rm -r --quiet $(git ls-files | grep -vE '^(identities/|modules/nixos/secrets\.yaml$|\.sops\.yaml$|docs/superpowers/|LICENSE)')
```
Expected: `git ls-files` lists only the kept paths.

- [ ] **Step 2: Bootstrap `flake.nix` by hand** with inputs `nixpkgs` (`github:nixos/nixpkgs/nixos-26.05`), `flake-parts` (`nixpkgs-lib.follows = "nixpkgs"`), `import-tree` (`github:denful/import-tree`), `den` (`github:denful/den`), `flake-file` (`github:denful/flake-file`), and `outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);`

- [ ] **Step 3: Write `modules/den.nix`** importing `inputs.den.flakeModules.dendritic`, `inputs.flake-file.flakeModules.dendritic`, `inputs.flake-file.flakeModules.auto-follow`, declaring the same inputs via `flake-file.inputs` (`systems = [ "x86_64-linux" "aarch64-darwin" ]`). Write `modules/flake/formatter.nix` (`nixfmt-tree`; `flake-file.formatter`), `modules/flake/devshell.nix` (`just`, `statix`, `deadnix`, `sops`, `age`, `nixfmt-tree`, `nvd`).

- [ ] **Step 4: Write the failing eval test** in `modules/flake/eval-tests.nix`: declare the `evalTests` option and the `eval-tests` check, plus one deliberately wrong test

```nix
evalTests.harness-reports-mismatch = { expr = 1; expected = 2; };
```

- [ ] **Step 5: Generate the flake and run it**

Run: `git add -A && nix run .#write-flake && nix flake check`
Expected: FAIL in `eval-tests` naming `harness-reports-mismatch: expected 2, got 1`.

- [ ] **Step 6: Replace it with a real test** `evalTests.no-hosts-yet = { expr = config.den.hosts; expected = { }; };` and write the `justfile` (recipes above, all run through `nix develop -c` when outside the shell, matching master's recipe naming). `check` = `format-check` + `lint` + `nix flake check` (which includes `check-flake-file` and `eval-tests`).

- [ ] **Step 7: Verify**

Run: `just check`
Expected: PASS. Then add a throwaway `flake-file.inputs.probe.url = "github:nixos/nixpkgs";` line, run `nix flake check`, expect `check-flake-file` FAIL; remove it.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor!: start den config from an empty tree"
```

---

### Task 2: Entity wiring, universal layer and the user

**Files:**
- Modify: `modules/den.nix`
- Create: `modules/system/{nix,locale,networking}.nix`, `modules/security/ssh.nix`, `modules/users/alexander.nix`, `modules/hardware/qemu-guest.nix`, `modules/hosts/base-vm/default.nix`, `modules/flake/home-manager.nix`, `modules/flake/nixpkgs.nix`
- Test: eval tests in the files above (each aspect file carries its own `evalTests`)

**Interfaces:**
- Consumes: `evalTests` (Task 1).
- Produces:
  - host option `stateVersion : str` (no default) → `system.stateVersion` and every HM user's `home.stateVersion`.
  - quirks `persist` and `persistHome` (declared, entries `{ directories ? [ ]; files ? [ ]; }`); consumer comes in Task 4.
  - `den.schema.conf` options `timeZone : str`, `locales : listOf str`, `layouts : listOf str` with the Global Constraints defaults, declared in `modules/system/locale.nix`.
  - user option `identity : str` (default `user.userName`), declared in `modules/security/ssh.nix`; authorized keys = `identities/<identity>/ssh.pub`.
  - `den.aspects.hardware.qemu-guest`; host `base-vm` (`x86_64-linux`, user `alexander`).
  - `den.schema.host.includes = [ hostname mutual-provider system.nix system.locale system.networking security.ssh ]`; `den.schema.user.includes = [ define-user ]`; `den.schema.user.classes = lib.mkDefault [ "homeManager" ]`; `den.migrations.user-host-content.acknowledged = true`; `den.default` sets `home-manager.useGlobalPkgs = true; useUserPackages = true;`.
  - `pkgs.unstable` overlay (one aspect, per den's nixpkgs guide) with `flake-file.inputs.nixpkgs-unstable`.

- [ ] **Step 1: Write failing eval tests** against `let c = config.flake.nixosConfigurations.base-vm.config;`

```nix
base-vm-hostname   = { expr = c.networking.hostName; expected = "base-vm"; };
base-vm-timezone   = { expr = c.time.timeZone; expected = "Europe/Kyiv"; };
base-vm-locale     = { expr = c.i18n.defaultLocale; expected = "en_US.UTF-8"; };
base-vm-state      = { expr = c.system.stateVersion; expected = "26.05"; };
base-vm-hm-state   = { expr = c.home-manager.users.alexander.home.stateVersion; expected = "26.05"; };
alexander-wheel    = { expr = lib.elem "wheel" c.users.users.alexander.extraGroups; expected = true; };
alexander-shell    = { expr = lib.getName c.users.users.alexander.shell; expected = "fish"; };
alexander-ssh-key  = { expr = c.users.users.alexander.openssh.authorizedKeys.keys;
                       expected = [ (lib.trim (builtins.readFile ../../identities/alexander/ssh.pub)) ]; };
sshd-hardened      = { expr = { inherit (c.services.openssh.settings) PasswordAuthentication PermitRootLogin; };
                       expected = { PasswordAuthentication = false; PermitRootLogin = "no"; }; };
unstable-overlay   = { expr = c.nixpkgs.pkgs ? unstable; expected = true; };
```

- [ ] **Step 2: Run to verify failure**

Run: `nix flake check` → FAIL (`base-vm` undefined).

- [ ] **Step 3: Implement** the files listed. `system.locale` sets `time.timeZone`, `i18n.defaultLocale = head locales`, `i18n.extraLocaleSettings` from the second locale, `console`/xkb layouts from `layouts`, reading them from `host`. `security.ssh` as on the dendritic branch (`PasswordAuthentication = false`, `PermitRootLogin = mkDefault "no"`, ed25519 host key) and emits `persist.files = [ "/etc/ssh/ssh_host_ed25519_key" "/etc/ssh/ssh_host_ed25519_key.pub" ]`. Users get keys via a `{ host, user }` function. `alexander` includes `den.batteries.primary-user` and `(den.batteries.user-shell "fish")`. `hardware.qemu-guest` imports `profiles/qemu-guest.nix`. Declare home-manager input in `modules/flake/home-manager.nix`.

- [ ] **Step 4: Run to verify pass**

Run: `just flake-write && just check` → PASS.

- [ ] **Step 5: Commit** `feat(den): wire entities, the universal layer and alexander`

---

### Task 3: Aspect settings, disko layout and the `server` host with disk parity

**Files:**
- Create: `modules/_lib/settings-type.nix` (den guide's generator, verbatim), `modules/storage/disko.nix`, `modules/hosts/server/{default.nix,_hardware.nix,_parity.nix,_disko-master.json,_filesystems-master.json}`
- Modify: `modules/den.nix` (`den.reservedKeys = [ "settings" ];`, host option `settings` typed by the generator)

**Interfaces:**
- Produces: `den.aspects.storage.disko` with settings `device : str` (no default), `swapSize : str` (default `"8G"`), `encrypted : bool` (default `true`), read as `host.settings.storage.disko.<name>` (confirm the exact path the generator produces from the nested aspect tree; adjust the doc example if it differs). Host `server` (`x86_64-linux`, user `alexander`, `settings.storage.disko = { device = "/dev/disk/by-id/ata-SSD_2TB_004208"; encrypted = false; }`). `_parity.nix` (`{ lib }: { … }`) exports `declarative : value -> value` (drop functions, `_`-prefixed keys, nulls; store paths → `"<path>"`), `withoutHook : devices -> devices` (nulls `disk.root.content.partitions.btrfs.content.postCreateHook`, which only formatting runs), and `mounts : fileSystems -> attrs` (`lib.mapAttrs (_: v: { inherit (v) neededForBoot device fsType options; })`). Tasks 4 and 6 import it from `modules/hosts/server/_parity.nix`.
- Layout values (from master): GPT; ESP partition `boot`, label/`-n` `boot`, size `1G`, vfat, `/boot`, `umask=0077`; btrfs partition attr `btrfs` (partition label `root`, `extraArgs = [ "-f" "-L root" ]`; the attr name must stay `btrfs` for parity), or, when encrypted, partition attr `encrypted` (label `root_encrypted`; master spells the attr `encryped`, a typo fixed here, safe because `server` is unencrypted) → luks `root` (`passwordFile = "/tmp/disk.key"`, `allowDiscards`, `crypttabExtraOpts = [ "fido2-device=auto" "token-timeout=10" ]`) when encrypted; subvolumes `@root` → `/` (blank snapshot `@root-blank` in `postCreateHook`), `@nix` → `/nix`, `@log` → `/var/log` (`subvol=log compress=zstd noatime`, neededForBoot), `@swap` → `/swap` (swapfile `swapSize`), `@persist` → `/persist` (neededForBoot), `@home` → `/home` (`subvol=home compress=zstd noatime`), `@data` → `/data` (`subvol=data noatime`); default mount options `compress=zstd noatime`.

- [ ] **Step 1: Capture master's layout as fixtures**

```bash
git -C . worktree add ../nix-config-master master
nix eval --json --impure --expr '
  let f = builtins.getFlake "git+file://'"$PWD"'/../nix-config-master";
      lib = f.inputs.nixpkgs.lib;
      p = import ./modules/hosts/server/_parity.nix { inherit lib; };
      c = f.nixosConfigurations.server.config;
  in p.declarative c.disko.devices' > modules/hosts/server/_disko-master.json
```
Do the same with `p.mounts c.fileSystems` → `_filesystems-master.json`. Write `_parity.nix` first (step needs it). Remove the worktree afterwards.

- [ ] **Step 2: Write failing eval tests** in `modules/hosts/server/default.nix`

```nix
server-disko-matches-master = { expr = withoutHook (declarative s.disko.devices); expected = withoutHook (lib.importJSON ./_disko-master.json); };
server-filesystems-match-master = { expr = mounts s.fileSystems; expected = lib.importJSON ./_filesystems-master.json; };
base-vm-encrypted = { expr = b.disko.devices.disk.root.content.partitions ? encrypted; expected = true; };
```
(`declarative`, `withoutHook`, `mounts` come from `_parity.nix`; `base-vm` sets `settings.storage.disko.device = "/dev/vda"` in this task.)

- [ ] **Step 3: Run** `nix flake check` → FAIL.
- [ ] **Step 4: Implement** the generator wiring, `storage.disko` (input `flake-file.inputs.disko`, module import, layout from settings), `server` host (+ `_hardware.nix` ported from master's `systems/x86_64-linux/server/hardware.nix`), and include `storage.disko` from `den.aspects.server` and `den.aspects.base-vm` directly for now (Task 4 moves it into `roles.base`).
- [ ] **Step 5: Run** `just flake-write && just check` → PASS.
- [ ] **Step 6: Commit** `feat(storage): disko layout as an aspect with per-host settings; server matches master's disk`

---

### Task 4: Impermanence, boot, sops, user password and `roles.base`

**Files:**
- Create: `modules/storage/impermanence.nix`, `modules/system/boot.nix`, `modules/security/{sops,user-password}.nix`, `modules/roles/base.nix`
- Move: `git mv modules/nixos/secrets.yaml secrets/nixos.yaml`; update the matching `path_regex` in `.sops.yaml` to `secrets/nixos.ya?ml$`
- Modify: `modules/hosts/{server,base-vm}/default.nix` (include `roles.base` instead of `storage.disko`)

**Interfaces:**
- Consumes: quirks `persist`/`persistHome` (Task 2), `storage.disko` and settings (Task 3).
- Produces:
  - `den.aspects.storage.impermanence` with setting `root : str` (default `"/persist"`): initrd systemd service `impermanence-rollback-root` (master's script: delete `@root` and nested subvolumes, snapshot `@root-blank` → `@root`; device label from `storage.disko`), collector `environment.persistence.<root> = { hideMounts = true; directories = [ "/var/lib/nixos" ] ++ quirk dirs; files = [ "/etc/machine-id" ] ++ quirk files; }` (`/var/log` is its own subvolume and needs no entry) and HM `home.persistence` from `persistHome`. It also sets `sops.age.sshKeyPaths = [ "<root>/etc/ssh/ssh_host_ed25519_key" ]` only when the sops module is present (`lib.optionalAttrs (options ? sops)`).
  - `den.aspects.security.sops`: sops-nix module, `defaultSopsFile = ../../secrets/nixos.yaml`, `flake-file.inputs.sops-nix`.
  - `den.aspects.security.user-password` in `den.schema.user.includes`: `{ user }` → nixos `sops.secrets."user-${user.userName}-password".neededForUsers = true; users.users.${user.userName}.hashedPasswordFile = …path; users.mutableUsers = false;`.
  - `den.aspects.system.boot`: systemd-boot, EFI, `boot.initrd.systemd.enable = true`.
  - `den.aspects.roles.base.includes = [ system.boot storage.disko storage.impermanence security.sops ]`.
- Decide (builder): which base directories impermanence always keeps; master kept `/.cache/nix/ /var/cache/ /var/db/sudo/ /var/lib/` — prefer contributing them through the `persist` quirk from the aspects that need them, keeping `/var/lib/nixos` and `/etc/machine-id` in the collector.

- [ ] **Step 1: Write failing eval tests** (`b` = base-vm config, `s` = server config)

```nix
persist-collects-ssh-key = { expr = lib.elem "/etc/ssh/ssh_host_ed25519_key" (map (f: f.filePath) b.environment.persistence."/persist".files); expected = true; };
rollback-unit           = { expr = b.boot.initrd.systemd.services ? impermanence-rollback-root; expected = true; };
sops-key-under-persist  = { expr = b.sops.age.sshKeyPaths; expected = [ "/persist/etc/ssh/ssh_host_ed25519_key" ]; };
sops-default-file       = { expr = baseNameOf (toString b.sops.defaultSopsFile); expected = "nixos.yaml"; };
password-from-sops      = { expr = b.users.users.alexander.hashedPasswordFile; expected = "/run/secrets-for-users/user-alexander-password"; };
server-still-matches    = { expr = withoutHook (declarative s.disko.devices); expected = withoutHook (lib.importJSON ../server/_disko-master.json); };
base-vm-builds          = { expr = lib.isString b.system.build.toplevel.drvPath; expected = true; };
```

- [ ] **Step 2: Run** `nix flake check` → FAIL.
- [ ] **Step 3: Implement** as specified above.
- [ ] **Step 4: Run** `just flake-write && just check` → PASS (`toplevel.drvPath` evaluates on darwin; building happens in CI).
- [ ] **Step 5: Commit** `feat(roles): base role with impermanence, sops and user passwords`

---

### Task 5: Install test for VM hosts

**Files:**
- Create: `modules/flake/install-tests.nix`
- Modify: `modules/den.nix` (quirk `installChecks`: entries are Python test-script snippets)

**Interfaces:**
- Consumes: hosts that `hasAspect den.aspects.hardware.qemu-guest`; `installChecks` quirk.
- Produces: `checks.<host.system>.install-<host>` = `(nixosConfigurations.<host>.extendModules { modules = [ testModule ]; }).config.system.build.installTest` (disko). The test module:
  - builds a throwaway age key + `secrets.yaml` encrypted to it at build time, with one entry per name in the host's `config.sops.secrets` (names come from the host, never listed in the test); `user-*-password` entries get `mkpasswd -m sha-512 test`, others the string `test`;
  - points sops at them (`defaultSopsFile = mkForce …`, `validateSopsFiles = false`, `age.keyFile = "/run/test-age.key"`, `age.sshKeyPaths = mkForce [ ]`), installing the key before `setupSecrets`/`setupSecretsForUsers` (as the dendritic branch does);
  - sets `swapSize = "256M"` through the test (disko's 4 GB test disks);
  - supplies the LUKS passphrase when `encrypted` (disko test harness);
  - `extraChecks` = base asserts + every `installChecks` entry from the host.
- Base asserts (Python, in this order): `wait_for_unit("multi-user.target")`; `succeed("systemctl is-active sshd.service")`; `succeed("id alexander")` — the user name comes from `host.users`, not a literal; `succeed("test -e /run/secrets-for-users/user-alexander-password")`; every collected persist path is a mount (`findmnt`); `touch /root-marker <root>/persist-marker`; `shutdown(); start(); wait_for_unit("multi-user.target")`; `fail("test -e /root-marker")`; `succeed("test -e <root>/persist-marker")`; the password secret exists again after the power cycle.

- [ ] **Step 1: Write failing eval tests**

```nix
install-test-exists  = { expr = config.allSystems.x86_64-linux.checks ? install-base-vm; expected = true; };
install-test-no-real = { expr = config.allSystems.x86_64-linux.checks ? install-server; expected = false; };
test-secrets-cover-host = { expr = testSecretNames "base-vm"; expected = lib.attrNames config.flake.nixosConfigurations.base-vm.config.sops.secrets; };
```
(`testSecretNames` is exported by `install-tests.nix` for exactly this test.)

- [ ] **Step 2: Run** `nix flake check` → FAIL.
- [ ] **Step 3: Implement** `modules/flake/install-tests.nix`.
- [ ] **Step 4: Run** `just check` → PASS on darwin (eval only). Run `nix eval .#checks.x86_64-linux.install-base-vm.drvPath` → a store path. The real run is Task 8's CI.
- [ ] **Step 5: Commit** `test(vm): install test for every qemu-guest host`

---

### Task 6: `roles.server`, tailscale and `server-vm`

**Files:**
- Create: `modules/system/headless.nix`, `modules/services/tailscale.nix`, `modules/roles/server.nix`, `modules/hosts/server-vm/default.nix`
- Modify: `modules/hosts/server/default.nix` (include `roles.server`)

**Interfaces:**
- Consumes: `roles.base`, `persist`, `installChecks`, `hardware.qemu-guest`.
- Produces:
  - `den.aspects.system.headless`: no docs/man/info, no fonts/X, `systemd.watchdog` runtime 30s, srvos server mixins only if adopted (builder's call; if used, `flake-file.inputs.srvos`).
  - `den.aspects.services.tailscale`: `sops.secrets."system-tailscale-auth-key" = { }`, `services.tailscale = { enable = true; authKeyFile = …; authKeyParameters.preauthorized = true; }`, autoconnect retry as on the dendritic branch, `persist.directories = [ "/var/lib/tailscale" ]`, `installChecks = [ ''machine.succeed("systemctl is-active tailscaled.service")'' ]`. The install test disables `tailscaled-autoconnect` (no network). ACL tags are out of scope (infra slice).
  - `den.aspects.roles.server.includes = [ roles.base system.headless services.tailscale ]`.
  - host `server-vm` (`x86_64-linux`, user `alexander`, `stateVersion = "26.05"`, `settings.storage.disko = { device = "/dev/vda"; encrypted = false; }`), includes `roles.server hardware.qemu-guest`.

- [ ] **Step 1: Write failing eval tests**

```nix
server-vm-tailscale     = { expr = sv.services.tailscale.enable; expected = true; };
server-vm-persists-ts   = { expr = lib.elem "/var/lib/tailscale" (map (d: d.dirPath) sv.environment.persistence."/persist".directories); expected = true; };
base-vm-no-tailscale    = { expr = b.services.tailscale.enable; expected = false; };
server-vm-disk-like-server = { expr = withoutDevice (declarative sv.disko.devices); expected = withoutDevice (declarative s.disko.devices); };
server-vm-install-check = { expr = config.allSystems.x86_64-linux.checks ? install-server-vm; expected = true; };
server-builds           = { expr = lib.isString s.system.build.toplevel.drvPath; expected = true; };
```
(`withoutDevice` drops `device` and swap size, the only intended differences.)

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** `just flake-write && just check` → PASS.
- [ ] **Step 5: Commit** `feat(roles): headless server role with tailscale; server-vm`

---

### Task 7: deploy-rs nodes

**Files:**
- Create: `modules/flake/deploy.nix`

**Interfaces:**
- Produces: host option `deploy : nullOr (submodule { hostname : str (default host.name); sshUser : str; })`, default `null`; `flake.deploy.nodes.<host>` for every NixOS host with `deploy != null` (`profiles.system.path = deploy-rs.lib.<system>.activate.nixos <config>`, `user = "root"`), built in this one module from `den.hosts`; `checks` from `deploy-rs.lib.<system>.deployChecks` for those nodes; `flake-file.inputs.deploy-rs`. `server` sets `deploy.sshUser = "alexander"`.

- [ ] **Step 1: Failing eval tests**

```nix
deploy-only-server = { expr = lib.attrNames config.flake.deploy.nodes; expected = [ "server" ]; };
deploy-server      = { expr = { inherit (config.flake.deploy.nodes.server) hostname sshUser; }; expected = { hostname = "server"; sshUser = "alexander"; }; };
```
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** `just flake-write && just check` → PASS.
- [ ] **Step 5: Commit** `feat(deploy): deploy-rs nodes from hosts that opt in`

---

### Task 8: Naming check, tooling and CI

**Files:**
- Create: `modules/flake/naming.nix`, `modules/flake/nh.nix` (`perSystem.packages = den.lib.nh.denPackages { fromFlake = true; } pkgs;`, as in den's default template), `.github/workflows/ci.yml`
- Modify: `justfile` (`build <host>`, `vm-test <host>`)

**Interfaces:**
- Produces:
  - `evalTests` from `naming.nix`: walk every category under `den.aspects` (top-level keys that are not hosts or users); fail with the path when a segment is a structural key (`den.lib.aspects.fx.keyClassification.isStructuralKey`), a class (`den.classes`) or a quirk (`den.quirks`); fail when a top-level host or user name equals a category; fail when `modules/<category>/<feature>.nix` (or `/default.nix`) doesn't exist for a declared feature path.
  - `just build <host>` = `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`; `just vm-test <host>` = `nix build .#checks.x86_64-linux.install-<host> -L` on x86_64 Linux, and on darwin prints `install tests run in CI (x86_64 KVM)` and exits 1.
  - CI on push/PR to `refactor/den-aspects` and `master`: `ubuntu-latest`, KVM enabled (udev rule for `/dev/kvm`), DeterminateSystems nix installer + magic cache, then `nix develop -c just check`, then `nix build .#checks.x86_64-linux.install-base-vm .#checks.x86_64-linux.install-server-vm -L`, then `nix build .#nixosConfigurations.server.config.system.build.toplevel`.

- [ ] **Step 1: Failing naming test**: add a temporary `den.aspects.system.user.nixos = { };` and expect `naming` to FAIL naming `system.user`. Remove it.
- [ ] **Step 2: Implement** `naming.nix`; **Run** `just check` → PASS.
- [ ] **Step 3: Write** the justfile recipes and the workflow.
- [ ] **Step 4: Push and verify CI**

Run: `git push -u origin refactor/den-aspects`, then `gh run watch`.
Expected: all steps green; both install tests pass. If an install test fails, fix it in the owning task's files and push again.
- [ ] **Step 5: Commit** `ci: check, install tests and server build on x86_64 KVM`

---

### Task 9: AGENTS.md and CLAUDE.md

**Files:**
- Create: `AGENTS.md`, `CLAUDE.md` (single line `@AGENTS.md`)

**Interfaces:**
- Consumes: the spec's mechanism map and naming convention; den's `AGENTS.md` code style; master's `AGENTS.md` sections on `nix develop` + `just`, recipe naming, secrets, Conventional Commits, branch names.
- Produces: `AGENTS.md` sections, in order: Overview (den's four concepts, links to den docs); Where things go (mechanism map table); Naming (the convention, reserved keys); How to add a feature / host / VM host / user / setting / quirk / input (each a short numbered recipe with the exact file and the eval test to add); Rules (anti-goals); Commands (`just` recipes, `vm-test` in CI, updating den: `just update`, read den's `whats-changed`, one PR); Code style (den's: `inherit` over `with`, comments explain why, stage new files before evaluating); Git (Conventional Commits, `<type>/<desc>` branches).

- [ ] **Step 1: Write** both files.
- [ ] **Step 2: Verify** every command in `AGENTS.md` runs (`just --list` contains each recipe named; `just check` passes) and each "how to add" recipe names a file pattern that exists.
- [ ] **Step 3: Commit** `docs: AGENTS.md for the den config`
