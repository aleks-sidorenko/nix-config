# Phone Tools CLI

## Goal

Provide CLI tools for mounting Android and iPhone devices as user-space FUSE
drives on Linux and pulling their camera roll (DCIM) to local disk for backup.
Organizing pulled files into the media library is a **separate, optional**
`media-import` step — `phone-tools` deliberately has no dependency on
`media-tools`.

## Background

Ported from [old dotfiles](https://github.com/aleks-sidorenko/dotfiles/blob/master/shell/plugins/img/img.plugin.zsh)
(`android_mount`/`iphone_mount` + `*_img_import` + `*_img_clean`). Improvements
over the original:

- **No `sudo`.** Uses user-space FUSE mounts (`ifuse`, `aft-mtp-mount`) instead
  of the old `sudo go-mtpfs` / `sudo umount -l`. Unmount uses the setuid
  `fusermount` from the NixOS security wrapper.
- **Read-only w.r.t. the phone.** Pulls files off the device with `rsync`; never
  writes back to the mount. (The old flow ran the importer directly against the
  mount, and `media-import` writes EXIF into its source — unsafe/slow on a phone.)
- **Composable.** Device/file management (`phone-*`) is fully decoupled from
  library organization (`media-import`). You compose the two yourself.

## Scope

- **Linux only** (`x86_64-linux` desktops: desktop, homebook, vm). macOS is out
  of scope — no clean CLI mount story there.
- **Both device types**: Android (MTP) and iPhone (`ifuse` + `usbmuxd`).
- **DCIM only.** Camera photos/videos. Other folders (Downloads, WhatsApp, …)
  are reachable via `phone-pull --from <subpath>` but are not the default.

## Conventions

- **User-space FUSE, no root.** All mounts/unmounts run as the logged-in user.
  Mounting relies on the setuid `fusermount` **and** `fusermount3` wrappers that
  `programs.fuse.enable` (default `true`) installs on `/run/wrappers/bin`. Both
  are needed: `ifuse` (iOS) builds against fuse2 → `fusermount -u`, while
  `aft-mtp-mount` (Android) builds against fuse3 → `fusermount3 -u`. Unmount
  therefore tries `fusermount3 -u || fusermount -u`. The `phone-tools` package
  must **not** bundle its own `fusermount`/`fuse` on PATH (a non-setuid helper
  cannot mount/unmount for a normal user). No `allow_other` is used, so
  `programs.fuse.userAllowOther` is not required.
- **Mount point.** `MOUNT_POINT="${PHONE_MOUNT:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/phone}"`.
  User-owned tmpfs, auto-cleaned on logout. Overridable via `PHONE_MOUNT`.
  `phone-mount` creates it (`mkdir -p`) and verifies it is empty before
  mounting; the directory is a stable path reused across mounts.
- **Phone is read-only.** `phone-pull` only reads from the mount. The only
  write operation to a device is the explicit, confirmation-gated `phone-clean`
  (both device types; iOS shows an AFC caveat — see below).
- **Pull semantics.** `phone-pull` copies with
  `rsync -rt --info=progress2 --no-perms --no-owner --no-group --size-only`.
  MTP/AFC mounts expose no perms/owner/symlinks and unreliable mtimes, so `-a`
  is wrong; `--size-only` gives dependable "skip files already pulled" behavior
  for a camera roll (filenames are effectively unique, so size collisions are a
  non-issue). Re-running only transfers files not already present locally.

## System prerequisites (Linux)

These are provided by the NixOS module (see Nix Architecture); listed here so
the runtime assumptions are explicit:

- **`usbmuxd` daemon** — required for iPhone pairing/AFC (`idevicepair`,
  `ifuse`). System-level; cannot come from home-manager.
- **MTP udev rules** — required for Android MTP. The `uaccess` tag that lets
  the active-session user open the raw USB device node is applied by udev
  rules; these are **not** installed merely by having the MTP binaries in the
  closure. Without them, MTP mounts fail with permission errors. The rules tag
  the `/dev/bus/usb` node and are library-independent, so they work even though
  `aft-mtp-mount` uses its own MTP stack rather than libmtp. `pkgs.libmtp` ships
  these rules. (`pkgs.android-udev-rules` was removed from nixpkgs — superseded
  by built-in systemd uaccess rules — so do **not** reference it.)
- **`fusermount` / `fusermount3` security wrappers** — created by
  `programs.fuse.enable` (default `true`); nothing extra to enable.

## Tools

All scripts live in the `phone-tools` package and share a small
`phone-common.sh` (device detection, `MOUNT_POINT` resolution, mount-state
checks, `print_info` / `print_error`, confirmation prompt). No code shared with
`media-tools`.

### `phone-mount`

Detect the connected device and mount it as a user FUSE drive.

**Detection order:**
1. If `idevice_id -l` lists a device → **iPhone**: pair if needed
   (`idevicepair pair`), then `ifuse "$MOUNT_POINT"`. (`usbmuxd` is
   socket-activated, so detection relies on `idevice_id` triggering activation
   rather than probing for a running process — see the usbmuxd-absent note.)
2. Else → **Android (MTP)**: `aft-mtp-mount "$MOUNT_POINT"`.
3. Explicit override: `phone-mount ios` / `phone-mount android`.

**Mount readiness.** FUSE mounts can return before the filesystem is usable, and
`aft-mtp-mount`'s backgrounding must not be assumed. After invoking the mounter,
`phone-mount` polls `mountpoint -q "$MOUNT_POINT"` with a short timeout before
reporting success, so a following `phone-pull` (e.g. inside `phone-backup`)
never races a not-yet-ready mount. If the poll times out, error out rather than
hang.

**Preconditions & guidance:**
- Creates `MOUNT_POINT` and confirms it is empty; if already mounted, report and
  exit 0 (idempotent).
- **GNOME/gvfs conflict (Android):** GNOME's `gvfs-mtp` auto-mounts the phone on
  plug-in and holds MTP's single initiator slot, so `aft-mtp-mount` fails with
  "device busy". `phone-mount` detects an existing gvfs MTP mount (e.g. under
  `/run/user/$(id -u)/gvfs/mtp:*`) and instructs the user to eject it first
  (Files → eject, or `gio mount -u`). iPhone/AFC is immune (usbmuxd multiplexes
  clients), so no gvfs handling is needed there.
- **usbmuxd absent vs no iOS device:** if the `usbmuxd` socket is missing
  entirely (module not enabled), an attached iPhone would otherwise silently
  fall through to the Android path. Detection checks for the socket — not a
  running process, since it is socket-activated — and, when absent, emits a
  targeted hint ("iPhone tooling needs `hardware.phone.enable`") instead of a
  confusing MTP error.
- **Android USB mode:** Android defaults to "charging only"; MTP endpoints
  appear only after the user selects "File Transfer / MTP" on the phone. The
  no-device error calls this out (alongside unlock / "allow access" hints).

**Usage:**
```
phone-mount [ios|android]
```

### `phone-unmount`

Unmount the FUSE drive via the setuid wrapper. Because Android (`aft-mtp-mount`,
fuse3) and iOS (`ifuse`, fuse2) use different helpers, it tries
`fusermount3 -u "$MOUNT_POINT" || fusermount -u "$MOUNT_POINT"`. No-op (exit 0)
if not mounted.

**Usage:**
```
phone-unmount
```

### `phone-pull`

Copy the camera roll from the mounted phone to a local directory via `rsync`.
Read-only with respect to the phone.

**Behavior:**
- Requires the phone to be mounted (errors with guidance to run `phone-mount`).
- Locates DCIM: `find "$MOUNT_POINT" -maxdepth 4 -type d -iname DCIM` (depth
  bounded — deep `find` over MTP is slow). This covers iPhone `DCIM/100APPLE…`,
  Android `Internal storage/DCIM/Camera`, `Internal shared storage/DCIM`, and
  SD-card variants. **All** matches are pulled (internal + SD); the log lists
  each source tree so the user sees what's being copied.
- `--from SUBPATH` overrides the default DCIM scope with a path relative to the
  mount root (e.g. `--from Download`), skipping discovery.
- Copies with the `rsync` flags from Conventions into `DEST`, preserving the
  DCIM subtree. Re-runs transfer only files missing locally.
- No DCIM found: informational message, exit 0 (nothing to do).

**Usage:**
```
phone-pull [DEST] [--from SUBPATH]
```
- `DEST` defaults to `~/Phone/<device>-YYYYMMDD/` where `<device>` is `ios` or
  `android` and the date is today (local). `phone-pull` only requires that a
  mount exists (not that this process created it), so `<device>` is re-derived
  in `phone-common.sh` — `idevice_id -l` non-empty ⇒ `ios`, else `android` — so
  a pull against an already-mounted device still names the directory correctly.

### `phone-clean`

Delete the camera roll on the device after an explicit `[y/N]` confirmation.
Operates on the same DCIM scope `phone-pull` uses. Requires the phone mounted.
Supports **both** Android and iPhone.

- **iPhone caveat (surfaced, not blocked).** Deleting files directly over AFC
  does not update the on-device Photos database — it can orphan thumbnails,
  leave "Recently Deleted" entries, and only affects what is actually present
  under `DCIM` (some of the modern photo store lives elsewhere). When the
  mounted device is an iPhone, the confirmation prompt shows this caveat
  explicitly before proceeding; the user decides. (Recommended clean-after-backup
  flow on iOS remains the Photos app, but the tool does not force it.)
- Prints the target path(s) and file count, then prompts before deleting; on
  iPhone the prompt additionally prints the AFC/Photos-DB caveat.
- Never deletes without confirmation; no `--force` in v1 (YAGNI).

**Usage:**
```
phone-clean [--from SUBPATH]
```

### `phone-backup`

Convenience wrapper for the full **device** flow: `mount → pull → unmount`.
Stops at "files are on local disk." Deliberately does **not** run `media-import`.

- `DEST` passed through to `phone-pull` (same default).
- Uses a cleanup trap that unmounts **only if this invocation performed the
  mount** — it never tries to unmount a device it didn't mount (e.g. when
  `phone-mount` itself failed, or the phone was already mounted).

**Usage:**
```
phone-backup [DEST]
```

## Composition (docs, not code)

Backup then optionally organize into the media library:

```
phone-backup ~/Phone/dump          # get DCIM off the phone to local disk
media-import --move ~/Phone/dump   # optional: organize into $MEDIA_HOME/All/YYYY/MM
```

Pointing `media-import --move` at the **local** pulled dir (never the phone) is
correct: it is fast, and its EXIF backfill writes to local files only.

## Error Handling

- No device detected by `phone-mount`: error with hints (check cable, unlock
  phone, tap "allow access", Android → select "File Transfer" mode).
- iPhone attached but `usbmuxd` absent: targeted hint to enable
  `hardware.phone`, not a misleading Android/MTP failure.
- iPhone not paired / not trusted: surfaces `idevicepair` output; instructs the
  user to unlock and tap "Trust".
- Android MTP "device busy": detected gvfs auto-mount; instruct to eject first.
- `phone-pull` / `phone-clean` when not mounted: error telling the user to run
  `phone-mount` first.
- `phone-clean` against iPhone: proceeds after showing the AFC/Photos-DB caveat
  in the confirmation prompt (not blocked).
- No DCIM found under the mount: informational, exit 0.
- Already mounted / already unmounted: idempotent no-ops (exit 0).

## Nix Architecture

### Package: `packages/phone-tools/`

`stdenvNoCC.mkDerivation` mirroring `packages/media-tools/` (install scripts to
`$out/bin`, shared lib to `$out/lib/phone-tools`, `wrapProgram` with runtime
deps on PATH). Scripts: `phone-mount`, `phone-unmount`, `phone-pull`,
`phone-clean`, `phone-backup`; shared `phone-common.sh`.

**Runtime deps** (wrapped onto PATH):
- `ifuse`, `libimobiledevice` — iPhone mount + pairing (`idevice_id`,
  `idevicepair`)
- `android-file-transfer` — Android MTP mount (`aft-mtp-mount`); actively
  maintained, more robust than `jmtpfs`/`go-mtpfs` on modern Android
- `rsync`, `coreutils`, `findutils`, `glib` (`gio`, for gvfs-eject guidance)
- `util-linux` — `mountpoint` (used by every script; not part of `coreutils`)

Each wrapper also prepends `$out/bin` to PATH so `phone-backup` can invoke
`phone-mount` / `phone-pull` by name independent of the ambient profile PATH.

Deliberately **not** on PATH:
- `fuse` / `fusermount` — must resolve to the setuid `/run/wrappers/bin`
  version, not a nixpkgs plain build (see Conventions).
- `exiftool` — organizing is `media-tools`' job.

### Home-manager: rename `roles/mobile` → `roles/phone`

The existing `modules/home/roles/mobile/` becomes `modules/home/roles/phone/`
(`nix-config.roles.phone.enable`). Its loose `mtpfs` / `jmtpfs` list is replaced
by the `phone-tools` package (which carries its own runtime deps):

```nix
options.${namespace}.roles.phone.enable =
  mkEnableOption "Android/iPhone mount + camera-roll backup tooling";

config = mkIf cfg.enable {
  home.packages = [ pkgs.${namespace}.phone-tools ];
};
```

Does **not** enable `media.tools` — the two are independent. The one existing
reference — the home `roles/desktop` sets `roles.mobile = enabled` — is updated
to `roles.phone = enabled`, so every desktop home continues to get phone tooling
by default under the new name.

### NixOS: new `modules/nixos/hardware/phone/`

Provides the two system prerequisites, option-gated:

```nix
options.${namespace}.hardware.phone.enable =
  mkBoolOpt false "USB phone integration (usbmuxd for iOS, libmtp udev rules for Android MTP)";

config = mkIf cfg.enable {
  services.usbmuxd.enable = true;               # iPhone pairing/AFC
  services.udev.packages = [ pkgs.libmtp ];     # Android MTP uaccess rules
};
```

**Wiring (single coherent switch).** The NixOS desktop role
(`modules/nixos/roles/desktop/`) sets `nix-config.hardware.phone.enable = true`,
so every graphical host has both the `usbmuxd` daemon and the MTP udev rules;
the home desktop role enables `roles.phone`, which adds the CLI tools per user. This resolves the earlier inconsistency of coupling the
NixOS daemon to the *home* role (home-manager can't toggle a NixOS service). A
headless host that somehow wants phone tooling can set `hardware.phone.enable`
directly. (Android MTP genuinely needs no *daemon*, but it does need the udev
rules — hence both go in this one module.)

## Testing

Follow the `packages/media-tools/test` pattern where practical. Device mounting
can't be unit-tested without hardware, so tests focus on the pure logic:

- **DCIM discovery** against a fake mount tree (iPhone-style `DCIM/100APPLE`,
  Android-style `Internal storage/DCIM/Camera`, SD-card `DCIM`, none) →
  correct path set, depth bound respected.
- **DEST default derivation** (`~/Phone/<device>-YYYYMMDD/`) given device type
  and a fixed date.
- **Mount-point resolution** honors `PHONE_MOUNT` / `XDG_RUNTIME_DIR` /
  `/run/user/$(id -u)` fallback.
- **Idempotent mount/unmount** guards (already-mounted / not-mounted → exit 0).
- **`phone-clean` iOS caveat** (device type = ios → confirmation prompt includes
  the AFC/Photos-DB warning; deletion proceeds on confirm).
- **`--from` override** resolves relative to mount root and skips discovery.

Mount/pair/rsync invocations and the gvfs-conflict path are validated manually
against real hardware (documented as a manual checklist), not in CI.

## Out of Scope (v1)

- macOS support.
- Non-DCIM auto-backup (available via `--from`, not defaulted).
- Two-way sync / pushing files to the phone.
- `phone-clean --force` (always interactive).
- Auto-running `media-import` from `phone-backup` (kept composable).
