# Books Management (Calibre-Web) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a native `calibre-web` NixOS service that hosts the user's book library on the home server, readable in a browser and on e-readers (OPDS), with web upload + metadata fetch — auto-enabled by the `media-server` role and backed up by restic.

**Architecture:** A new snowfall module `modules/nixos/services/media/calibre-web/` wraps upstream `services.calibre-web`, exposes it behind the existing nginx proxy as `books.local`, seeds an empty Calibre library via a oneshot init unit, and stores the library at `/data/media/Books`. The `media-server` role enables it and adds the library to restic via a new reusable `extraPaths` option. A `just calibre-import` recipe migrates the user's existing local library once.

**Tech Stack:** Nix / NixOS modules, snowfall-lib, `services.calibre-web` (nixpkgs 0.6.25), `calibre` (`calibredb`), nginx reverse proxy, restic, just.

**Spec:** `docs/specs/2026-08-03-books-management-calibre-web-design.md`

**Reference modules (copy their idioms):**
- `modules/nixos/services/media/jellyfin/default.nix` — closest pattern (native service + nginx vhost + tmpfiles + package)
- `modules/nixos/services/media/radarr/default.nix` — user block + systemd customization idiom
- `modules/nixos/services/media/default.nix` — the `enabled` disjunction + shared `media` group
- `modules/nixos/roles/media-server/default.nix` — role wiring + `categories`/`dirs`
- `lib/defaults/default.nix` — `network.ports`
- `modules/nixos/services/backup/restic/default.nix` — `paths`/`extraPaths`

**Upstream facts already verified (do not re-litigate):**
- `services.calibre-web` options: `enable`, `listen.{ip,port}`, `dataDir`, `user`, `group`, `openFirewall`, `options.{calibreLibrary,enableBookUploading,enableBookConversion,enableKepubify}`.
- Upstream `listen.ip` defaults to `"::1"` — MUST override to `"127.0.0.1"` because the nginx wrapper hardcodes `proxyPass http://127.0.0.1:<port>`.
- Upstream creates `users.users.calibre-web` when `user == "calibre-web"` (group = `cfg.group`), and `users.groups.calibre-web` only when `group == "calibre-web"`. We use `group = "media"`, so we rely on the `media` aggregate to create the group — hence the disjunction edit (Task 3) is REQUIRED.
- Upstream `ExecStartPre` runs `test -f <library>/metadata.db` and aborts if missing → the init unit (Task 4) must run first.
- Upstream already creates the `dataDir` tmpfiles rule → do NOT duplicate it.

**Validation note (Nix, not xUnit):** "tests" here are `nix eval` on the new option (fails before, passes after), `just build` (evaluates the `server` closure), and `just check` (format + lint). Full functional validation (upload/read/OPDS/backup) runs after deploy in Task 7.

---

### Task 1: Add the calibre-web port to `lib/defaults`

**Files:**
- Modify: `lib/defaults/default.nix` (the `network.ports` attrset)

- [ ] **Step 1: Write the failing check**

Run: `nix eval --raw ".#lib.x86_64-linux.defaults.network.ports.calibre-web.web" 2>&1 | tail -1`
Expected: FAIL — attribute `calibre-web` missing (error mentioning it does not exist).

> If that flake lib path differs, use: `nix eval .#nixosConfigurations.server.config.nix-config` is not it — instead just proceed to build in Step 3, which will surface the missing attr when Task 5 references it. The eval check is a convenience, not a gate.

- [ ] **Step 2: Add the port**

In `lib/defaults/default.nix`, inside `network.ports`, next to the other services (e.g. after the `prowlarr` block), add:

```nix
        calibre-web = {
          web = 8083;
        };
```

- [ ] **Step 3: Verify it resolves**

Run: `nix eval --raw ".#lib.x86_64-linux.defaults.network.ports.calibre-web.web" 2>&1 | tail -1`
Expected: `8083` (or, if that lib attr path isn't exported, defer verification to Task 5's build).

- [ ] **Step 4: Commit**

```bash
git add lib/defaults/default.nix
git commit -m "feat(defaults): add calibre-web web port (8083)"
```

---

### Task 2: Add a reusable `extraPaths` option to the restic module

**Files:**
- Modify: `modules/nixos/services/backup/restic/default.nix`

- [ ] **Step 1: Fold `extraPaths` into the computed `paths`**

In the `let` block, change the `paths` binding from:

```nix
  paths = [
    "/home"
    "/root"
  ]
  ++ persistence.dirs config;
```

to:

```nix
  paths = [
    "/home"
    "/root"
  ]
  ++ persistence.dirs config
  ++ cfg.extraPaths;
```

- [ ] **Step 2: Declare the option**

In `options.${namespace}.services.backup.restic`, directly after the existing `paths = mkOpt ...` option, add:

```nix
    extraPaths = mkOpt (types.listOf types.str) [ ] "Additional paths to include in backups (appended to the computed defaults)";
```

> Rationale (from spec): `paths` default is a `default`, not a merged definition, so a downstream `mkAfter`/override on `paths` would DROP the computed defaults. Appending a separate `extraPaths` option avoids that.

- [ ] **Step 3: Verify it evaluates**

Run: `nix eval ".#nixosConfigurations.server.config.nix-config.services.backup.restic.extraPaths" 2>&1 | tail -1`
Expected: `[ ]` (empty list — nothing sets it yet).

- [ ] **Step 4: Commit**

```bash
git add modules/nixos/services/backup/restic/default.nix
git commit -m "feat(restic): add extraPaths option for extra backup paths"
```

---

### Task 3: Register calibre-web in the media aggregate disjunction

**Files:**
- Modify: `modules/nixos/services/media/default.nix`

- [ ] **Step 1: Add to the `enabled` disjunction**

In the `let` block, extend the `enabled` expression to include calibre-web:

```nix
  enabled =
    config.${namespace}.services.media.minidlna.enable
    || config.${namespace}.services.media.qbittorrent.enable
    || config.${namespace}.services.media.jellyfin.enable
    || config.${namespace}.services.media.radarr.enable
    || config.${namespace}.services.media.prowlarr.enable
    || config.${namespace}.services.media.calibre-web.enable;
```

> REQUIRED: calibre-web's `group` default dereferences `services.media.group`, and the shared `media` group is only created when `services.media.enable` is true. Without this, enabling calibre-web alone would reference a non-existent group. (This disjunction already omits `sonarr` — pre-existing; do not fix here.)

- [ ] **Step 2: Verify (deferred)**

This edit references `services.media.calibre-web.enable`, which the option (Task 4) defines. Evaluation is verified together in Task 5. No standalone run.

- [ ] **Step 3: Commit**

```bash
git add modules/nixos/services/media/default.nix
git commit -m "feat(media): include calibre-web in the media enable disjunction"
```

---

### Task 4: Create the calibre-web service module

**Files:**
- Create: `modules/nixos/services/media/calibre-web/default.nix`

- [ ] **Step 1: Write the module**

Create `modules/nixos/services/media/calibre-web/default.nix` with exactly:

```nix
{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services.media.calibre-web;
in
{
  options.${namespace}.services.media.calibre-web = {
    enable = mkEnableOption "Enable Calibre-Web book library";

    user = mkOpt types.str "calibre-web" "User to run Calibre-Web as";

    group = mkOpt types.str config.${namespace}.services.media.group "Group to run Calibre-Web as";

    libraryDir = mkOpt types.str "/data/media/Books" "Calibre library directory (contains metadata.db)";

    dataDir = mkOpt types.str "/var/lib/calibre-web" "Directory where Calibre-Web stores its app data";

    package = mkOpt types.package pkgs.calibre-web "Calibre-Web package to use";

    webPort =
      mkOpt types.port defaults.network.ports.calibre-web.web
        "Port for the Calibre-Web web interface";
  };

  config = mkIf cfg.enable {

    ${namespace} = {
      services.networking.nginx = {
        virtualHosts = {
          calibre-web = {
            serverName = hosts.local "books";
            port = cfg.webPort;
            # Books/comics can be large; allow big uploads through the proxy.
            clientMaxBodySize = "512m";
          };
        };
      };
    };

    services.calibre-web = {
      enable = true;
      inherit (cfg) package;
      listen = {
        # nginx proxies to 127.0.0.1; upstream defaults to ::1 which would not connect.
        ip = "127.0.0.1";
        port = cfg.webPort;
      };
      inherit (cfg) user;
      inherit (cfg) group;
      inherit (cfg) dataDir;
      # Access is via nginx only; do not expose the raw port on the firewall.
      openFirewall = false;
      options = {
        calibreLibrary = cfg.libraryDir;
        enableBookUploading = true;
        enableBookConversion = true;
        enableKepubify = true;
      };
    };

    # Bootstrap an empty Calibre library if none exists, so calibre-web's
    # ExecStartPre metadata.db check passes on a fresh deploy. Runs in its own
    # unsandboxed oneshot before (and required by) calibre-web, avoiding both the
    # ExecStartPre ordering hazard and the hardened sandbox of the calibre-web unit.
    systemd.services.calibre-web-init = {
      description = "Initialize an empty Calibre library for Calibre-Web";
      before = [ "calibre-web.service" ];
      requiredBy = [ "calibre-web.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
      };
      script = ''
        if [ ! -f "${cfg.libraryDir}/metadata.db" ]; then
          echo "No Calibre library at ${cfg.libraryDir}; creating an empty one..."
          ${pkgs.calibre}/bin/calibredb --with-library="${cfg.libraryDir}" list >/dev/null
        fi
      '';
    };

    # Create the library directory (owned by the service user/media group) before
    # the init unit runs. Do NOT declare dataDir here — upstream already does.
    systemd.tmpfiles.rules = [
      "d ${cfg.libraryDir} 0775 ${cfg.user} ${cfg.group} -"
    ];

    # calibredb (bootstrap + migration) and ebook-convert.
    environment.systemPackages = [ pkgs.calibre ];
  };
}
```

- [ ] **Step 2: Format**

Run: `just format modules/nixos/services/media/calibre-web/default.nix`
Expected: file reformatted (or already formatted), no errors.

- [ ] **Step 3: Verify the option now exists**

Run: `nix eval ".#nixosConfigurations.server.config.nix-config.services.media.calibre-web.enable" 2>&1 | tail -1`
Expected: `true` (it will already be enabled once Task 5 lands; before Task 5 this prints `false`). Either boolean = option resolves = success.

- [ ] **Step 4: Commit**

```bash
git add modules/nixos/services/media/calibre-web/default.nix
git commit -m "feat(media): add calibre-web book library service module"
```

---

### Task 5: Wire calibre-web into the media-server role + backup

**Files:**
- Modify: `modules/nixos/roles/media-server/default.nix`

- [ ] **Step 1: Add the Books category**

In the `categories` rec set, add a `books` entry (keep it OUT of `all`, which feeds download categories):

```nix
  categories = rec {
    movies = "Movies";
    series = "Series";
    books = "Books";
    all = [
      movies
      series
    ];
  };
```

- [ ] **Step 2: Enable the service + register the backup path**

In `config.${namespace}`, add the calibre-web service under `services.media` and the library to restic under `services.backup.restic`:

```nix
    ${namespace} = {

      services = {

        media = {
          # ... existing qbittorrent/jellyfin/radarr/sonarr/prowlarr/minidlna ...

          calibre-web = {
            enable = true;
            libraryDir = dirs.mediaDir categories.books;
          };
        };

        backup.restic.extraPaths = [ (dirs.mediaDir categories.books) ];

      };

    };
```

> `dirs.mediaDir categories.books` resolves to `/data/media/Books`. Place `calibre-web` inside the existing `media = { ... }` block and `backup.restic.extraPaths` as a sibling `services` key — do not create a second `services` attr.

- [ ] **Step 3: Build the server closure**

Run: `just build server` (or `nix build .#nixosConfigurations.server.config.system.build.toplevel --no-link`)
Expected: PASS — evaluates and builds. If `calibre` must build from source on aarch64 (not cached), this may take a long time; that is expected (see spec heads-up), not a failure.

- [ ] **Step 4: Confirm wiring evaluates correctly**

Run:
```bash
nix eval ".#nixosConfigurations.server.config.nix-config.services.media.calibre-web.libraryDir"
nix eval ".#nixosConfigurations.server.config.nix-config.services.backup.restic.extraPaths"
nix eval ".#nixosConfigurations.server.config.services.calibre-web.options.calibreLibrary"
```
Expected: `"/data/media/Books"`, `[ "/data/media/Books" ]`, `"/data/media/Books"` respectively.

- [ ] **Step 5: Commit**

```bash
git add modules/nixos/roles/media-server/default.nix
git commit -m "feat(media-server): enable calibre-web and back up the book library"
```

---

### Task 6: Add the `just calibre-import` migration recipe

**Files:**
- Modify: `justfile`

- [ ] **Step 1: Add the recipe**

Add near the other host-facing recipes (e.g. after `deploy`). Note SSH addressing: connect as the primary user (`alexander`) — root login is disabled — and escalate with passwordless sudo.

```just
# Migrate a local Calibre library to the server (one-time, after first deploy)
# Usage:
#   just calibre-import ~/Calibre\ Library                 # to server as alexander
#   just calibre-import /path/to/lib server alexander
calibre-import library_path hostname="server" username="alexander":
    @echo "📚 Importing Calibre library from '{{library_path}}' to {{username}}@{{hostname}}:/data/media/Books ..."
    @test -f "{{library_path}}/metadata.db" || { echo "❌ '{{library_path}}/metadata.db' not found — pass the Calibre library folder"; exit 1; }
    rsync -a --info=progress2 --rsync-path="sudo rsync" "{{library_path}}/" "{{username}}@{{hostname}}:/data/media/Books/"
    ssh {{username}}@{{hostname}} 'sudo chown -R calibre-web:media /data/media/Books'
    ssh {{username}}@{{hostname}} 'sudo systemctl restart calibre-web'
    @echo "✅ Import complete. Open http://books.local and verify your library."
```

- [ ] **Step 2: Verify the recipe parses**

Run: `just --show calibre-import`
Expected: prints the recipe body without a parse error.

- [ ] **Step 3: Commit**

```bash
git add justfile
git commit -m "feat(just): add calibre-import recipe to migrate a local library"
```

---

### Task 7: Validate the whole change (CI-safe + functional)

**Files:** none (validation only)

- [ ] **Step 1: Format + lint (CI-safe umbrella)**

Run: `just check`
Expected: PASS (format-check + statix + deadnix clean). If deadnix flags the new `books`/`extraPaths` as unused, confirm they ARE referenced (Task 5); fix genuine issues, then re-run.

- [ ] **Step 2: Flake check**

Run: `just flake-check` (`nix flake check`)
Expected: PASS.

- [ ] **Step 3: Deploy to the server**

Run: `just deploy server --remote-build`
Expected: deploy succeeds; `calibre-web-init.service` runs, then `calibre-web.service` becomes active.

Verify on the host:
```bash
ssh alexander@server 'systemctl is-active calibre-web-init.service calibre-web.service'
ssh alexander@server 'test -f /data/media/Books/metadata.db && echo library-ok'
```
Expected: `active`/`active` (init may show `inactive (dead)`+`SUCCESS` as a completed oneshot — check `systemctl status` shows `code=exited, status=0`), and `library-ok`.

- [ ] **Step 4: Functional check — browser + upload + metadata**

- Open `http://books.local` on a LAN device; log in (default `admin`/`admin`, change password).
- Click Upload, add a test `.epub`; confirm the "fetch metadata" flow populates cover/author.
- Open the book in the in-browser reader.

Expected: all succeed.

- [ ] **Step 5: Functional check — OPDS (e-reader)**

- On an OPDS client (KOReader/Marvin/etc.), add catalog `http://books.local/opds` with the calibre-web login; download a book.

Expected: catalog lists books; download works.

- [ ] **Step 6: Functional check — backup path**

Run: `ssh alexander@server 'systemctl cat restic-backups-*.service | grep -- /data/media/Books'`
Expected: `/data/media/Books` appears in the restic invocation (backup will include it on the next 03:00 run; optionally trigger `sudo systemctl start restic-backups-<name>.service` to confirm).

- [ ] **Step 7: Migrate the real library (one-time)**

Run: `just calibre-import "<path-to-your-local-Calibre-Library>"`
Then re-open `http://books.local` and confirm the migrated library shows, and the admin user/settings in `app.db` are retained.

- [ ] **Step 8: Final commit / close-out**

Nothing to commit if Steps 1–2 were clean. Reference issue #56 when merging (see finishing-a-development-branch).

---

## File Structure Summary

| File | Change | Responsibility |
| --- | --- | --- |
| `lib/defaults/default.nix` | modify | Declare `calibre-web.web = 8083` port |
| `modules/nixos/services/backup/restic/default.nix` | modify | Add reusable `extraPaths` option |
| `modules/nixos/services/media/default.nix` | modify | Include calibre-web in the media enable disjunction |
| `modules/nixos/services/media/calibre-web/default.nix` | create | The calibre-web service module (nginx vhost, service, init oneshot, tmpfiles, package) |
| `modules/nixos/roles/media-server/default.nix` | modify | Books category, enable calibre-web, restic `extraPaths` |
| `justfile` | modify | `calibre-import` migration recipe |

## Out of Scope (do not implement)

Readarr / auto-acquisition; calibre-web-automated / auto-ingest folder; Tailscale off-home access; send-to-Kindle via SMTP; public-internet exposure / ACME; reverse-proxy SSO.
