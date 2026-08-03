# Books management (Calibre-Web) — Design

**Issue:** #56 — Books management (Readarr and/or Calibre)
**Date:** 2026-08-03
**Status:** Approved (design)

## Problem

The user maintains a book library and wants to:

1. Store the library on the home server (RPi4, `aarch64-linux/server`) instead of only locally.
2. Read books **in a browser** and **on e-reader devices**.
3. Add new books conveniently: **upload a file + fetch metadata** (covers, author,
   series). The user finds books themselves — no automated acquisition is wanted.

## Decision summary

| Decision | Choice |
| --- | --- |
| Tool | **`calibre-web`** (native `services.calibre-web`, nixpkgs 0.6.25) |
| Readarr | **Out of scope** — user does not want auto-acquisition; Readarr is discontinued/unmaintained (2025) |
| Container vs native | **Native** NixOS service module, matching radarr/sonarr/jellyfin |
| Role wiring | **Auto-enabled** via the `media-server` role |
| Library location | `/data/media/Books` (new "Books" category, sibling of Movies/Series) |
| App data | `/var/lib/calibre-web` (persisted by impermanence, in restic paths) |
| Backup | **Library `/data/media/Books` MUST be in restic** (small, hand-curated) |
| Web access | nginx vhost `books.local`, LAN-only |
| E-reader access | OPDS feed at `books.local/opds` |
| Off-home access | **Out of scope** (Tailscale not enabled on server today) |
| Migration | One-time `just calibre-import <local-library-path>` recipe |

## Why calibre-web (not calibre-web-automated, not Readarr)

- `calibre-web` natively provides: web **upload** button, per-book **metadata
  fetch**, in-browser **reader**, **OPDS** for e-readers, optional format
  **conversion** and Kobo `.kepub` support — 100% of the stated requirements.
- It is packaged in nixpkgs with a first-class NixOS module, so it matches the
  repo's existing pattern (radarr/sonarr/jellyfin are all native service modules,
  never containers).
- `calibre-web-automated` (a maintained fork with a watched auto-ingest folder)
  was rejected: it is not in nixpkgs (would require a Podman container, off-pattern)
  and its headline drop-folder feature is unnecessary — the user only needs
  web-upload, which vanilla calibre-web does.
- Readarr (the *arr for books) was rejected: the user does not want automated
  acquisition, and Readarr is discontinued/unmaintained as of 2025.

## Architecture

New module: `modules/nixos/services/media/calibre-web/default.nix`, following the
structure of `modules/nixos/services/media/jellyfin/default.nix`.

### Options (`nix-config.services.media.calibre-web`)

- `enable` — `mkEnableOption`.
- `user` — default `"calibre-web"` (system user).
- `group` — default `config.${namespace}.services.media.group` (the shared
  `"media"` group), so book files are group-readable consistently with other media.
- `libraryDir` — default `/data/media/Books`. The Calibre library directory
  (contains `metadata.db` + book files). Overridden by the role.
- `dataDir` — default `/var/lib/calibre-web`. Calibre-Web app data (`app.db`:
  users, reading progress, bookmarks, shelves, settings).
- `webPort` — from `lib/defaults` (`defaults.network.ports.calibre-web.web`, value
  `8083` — calibre-web's default).

### `config` (under `mkIf cfg.enable`)

1. **nginx vhost** — add `calibre-web` vhost via
   `nix-config.services.networking.nginx.virtualHosts`:
   `serverName = hosts.local "books"`, `port = cfg.webPort`. This yields
   `http://books.local`. Set a generous `clientMaxBodySize` (e.g. `"512m"`) so large
   book/comic uploads through the proxy aren't rejected.
2. **System user** — the upstream module already creates the `calibre-web` user, and
   creates a `calibre-web` *group* only when `group == "calibre-web"`. Since we set
   `group = "media"`, no stray group is created. Declaring `users.users.${cfg.user}`
   ourselves (matching the radarr/prowlarr blocks) is harmless/idempotent but optional
   — keep it minimal and defer to upstream where values match.
3. **Upstream service** — configure `services.calibre-web`:
   - `enable = true`
   - `listen.ip = "127.0.0.1"` (nginx proxies to it), `listen.port = cfg.webPort`
   - `user` / `group` / `dataDir` from `cfg`
   - `openFirewall = false` (access is via nginx only; do not expose the raw port)
   - `options.calibreLibrary = cfg.libraryDir`
   - `options.enableBookUploading = true` (the upload button)
   - `options.enableBookConversion = true` (pulls in calibre's `ebook-convert`)
   - `options.enableKepubify = true` (Kobo `.kepub` support for e-readers)
   > Pass `libraryDir`/`dataDir` as **strings**, not path literals, so they are not
   > copied into the Nix store.
4. **Library bootstrap (critical)** — the upstream module's `ExecStartPre` fails if
   `${libraryDir}/metadata.db` does not exist. The module MUST guarantee a valid
   Calibre library exists before the service starts. Implement this as a **separate
   oneshot unit `calibre-web-init.service`**, NOT a `preStart` on `calibre-web`:
   - Rationale: NixOS maps `preStart` to `ExecStartPre` which *concatenates* with the
     upstream module's own `ExecStartPre` (order across modules is not guaranteed, so
     the upstream `metadata.db` check may run first and abort). Also, the upstream
     `calibre-web` unit is heavily hardened (`MemoryDenyWriteExecute`,
     `SystemCallFilter=~@privileged`, `ProtectHome`, restricted `ReadWritePaths`),
     which can block `calibredb` (Python/Qt). So run the init in its own unsandboxed
     unit.
   - Unit shape: `Type=oneshot`, `User=calibre-web`, `Group=media`,
     `before = [ "calibre-web.service" ]`, `requiredBy = [ "calibre-web.service" ]`.
   - Command (idempotent): if `metadata.db` is absent, create an empty library —
     `${pkgs.calibre}/bin/calibredb --with-library=${cfg.libraryDir} list` initializes
     an empty `metadata.db` headlessly when the dir has none. Guard with
     `test ! -f ${cfg.libraryDir}/metadata.db` and `chown -R calibre-web:media
     ${cfg.libraryDir}` afterward. This lets a fresh deploy come up healthy before the
     user has migrated anything; migration then populates/replaces the library.
5. **Directories** — `systemd.tmpfiles.rules` to create `cfg.libraryDir` (owned
   `calibre-web:media`, mode `0775`), same idiom as radarr/jellyfin. Do **not** add a
   `cfg.dataDir` tmpfiles rule — the upstream module already creates `dataDir`
   (mode `0700`); duplicating it is redundant.
6. **Package** — add `calibre` to `environment.systemPackages` (provides `calibredb`
   for bootstrap/migration and `ebook-convert`). Enabling `enableBookConversion`/
   `enableKepubify` already pulls `calibre` into the closure, so this doesn't grow it.
   Heads-up: `calibre` is a large closure on **aarch64/RPi4**; if it's not in the
   binary cache for aarch64 the first deploy may build it (slow). Note this in the
   migration/first-deploy docs.

### Media aggregate + role wiring

- `modules/nixos/services/media/default.nix` — add `calibre-web.enable` to the
  hand-maintained `enabled` disjunction that drives `services.media.enable`. This is
  **required**: calibre-web's `group` default dereferences `services.media.group`, so
  enabling calibre-web alone must still switch `services.media.enable` on to create the
  shared `media` group. (Note: this disjunction already omits `sonarr` — pre-existing
  tech-debt, not fixed here.)
- `modules/nixos/roles/media-server/default.nix`:
  - Add a `books = "Books"` entry to the `categories` set (and to `categories.all`
    only if that list is used for download categories — Books has no downloader, so
    likely keep it out of `all` and reference `categories.books` directly).
  - Enable `calibre-web = { enable = true; libraryDir = dirs.mediaDir categories.books; }`.

### `lib/defaults` port

Add to `defaults.network.ports`:

```nix
calibre-web = {
  web = 8083;
};
```

## Backup

The upstream default restic `paths` are computed (`/home`, `/root`, persisted
dirs) and deliberately **exclude `/data`** media. Book libraries are tiny and
hand-curated, so `/data/media/Books` must be added to restic.

**Approach:** add a reusable `extraPaths` option to the restic module rather than
overriding the computed `paths` (a `mkAfter` on `paths` would drop the default list,
since the default is a `default`, not a merged definition).

- `modules/nixos/services/backup/restic/default.nix`:
  - Add `extraPaths = mkOpt (types.listOf types.str) [ ] "Additional paths to back up"`.
  - Append it in the `paths` default: `paths = [ "/home" "/root" ] ++ persistence.dirs config ++ cfg.extraPaths`
    (or fold `extraPaths` into the computed value so an explicit `paths` override
    still wins). Keep the merge order deterministic.
- The `media-server` role (or the calibre-web module) sets
  `nix-config.services.backup.restic.extraPaths = [ "/data/media/Books" ]`.

`app.db` (reading progress, users, shelves) lives under `/var/lib/`, which is
already persisted and inside restic's default paths — no extra work.

## Migration (one-time)

The user has an existing **local** Calibre library. Provide a `just` recipe:

```
just calibre-import <local-library-path> [hostname=server]
```

**SSH addressing (critical):** root SSH login is **disabled** on the server
(`security.ssh.rootLogin` defaults `false` → `PermitRootLogin no`). The recipe MUST
connect as the **primary user** (`alexander`, same as deploy-rs `sshUser = user`) and
escalate via passwordless sudo (server role sets `security.sudo.wheelNeedsPassword =
false`). Do NOT use `root@server`. The host token `server` resolves fine (darwin
`/etc/hosts` maps both `server` and `server.local` → 10.0.0.40).

Behavior:
1. `rsync -a --info=progress2 --rsync-path="sudo rsync" <local-library-path>/ ${user}@<host>:/data/media/Books/`
   (trailing slashes to copy contents including `metadata.db`; `--rsync-path="sudo rsync"`
   so the remote side can write under `/data`).
2. `ssh ${user}@<host> 'sudo chown -R calibre-web:media /data/media/Books'`.
3. `ssh ${user}@<host> 'sudo systemctl restart calibre-web'` so it re-reads the migrated
   `metadata.db`.

`user`/`hostname` default to the repo's primary user and `server`; parameterize the
`just` recipe. Documented in the spec and `justfile`. Run once after the first deploy.
Because `/data` persists (separate btrfs subvolume, untouched by the root wipe), the
library survives reboots and impermanence wipes.

## Access model

- **Browser:** `http://books.local` on the home LAN — in-browser reader, upload,
  metadata edit/fetch, shelves.
- **E-reader:** OPDS at `http://books.local/opds` (add as an OPDS catalog in
  KOReader / Marvin / Moon+ Reader / PocketBook, using the calibre-web login).
- **Auth:** calibre-web's built-in login (default `admin`/`admin` — change on first
  login). No reverse-proxy auth wired (LAN-only, low risk). Unlike the *arr XML
  config, calibre-web stores auth in `app.db`, so no SOPS secret/template is needed
  for issue 56.
- **Off-home (Tailscale):** explicitly out of scope. If wanted later, enable
  `nix-config.services.networking.tailscale` on the server; `books.local` (or the
  tailnet IP) then reaches calibre-web + OPDS from anywhere on the tailnet.

## Out of scope (YAGNI)

- Readarr / automated acquisition.
- calibre-web-automated / auto-ingest folder / network share / Syncthing.
- Send-to-Kindle via SMTP email (could be a later enhancement; needs SMTP + a SOPS
  secret).
- Public-internet exposure via `sidorenko.me` / ACME.
- Reverse-proxy SSO/auth.

## Testing / validation

- `just format` + `just check` (statix/deadnix/format).
- `just build` (or `nix flake check`) — evaluates `server` config with the new module.
- Deploy to server; verify:
  - `systemctl status calibre-web` is active (empty library bootstrap works on a
    fresh library).
  - `http://books.local` loads; log in; **upload** a test `.epub` and confirm
    **metadata fetch** populates cover/author.
  - Open the book in the browser reader.
  - Add `http://books.local/opds` on an e-reader/OPDS client and download a book.
  - Run `just calibre-import <path>`; confirm the migrated library appears and
    `app.db` retains the admin user.
  - Confirm `/data/media/Books` is listed in the restic backup paths
    (`systemctl cat restic-backups-*` or a dry-run) and a backup run includes it.
