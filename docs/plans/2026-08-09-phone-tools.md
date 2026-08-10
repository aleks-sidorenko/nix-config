# Phone Tools CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `phone-tools` package (mount/unmount/pull/clean/backup Android + iPhone camera roll on Linux) plus the NixOS/home-manager wiring to enable it on desktops.

**Architecture:** A snowfall custom package (`packages/phone-tools/`) of bash scripts wrapped with runtime deps, mirroring the existing `packages/media-tools/` pattern. User-space FUSE mounts (`ifuse` for iOS via `usbmuxd`, `aft-mtp-mount` for Android MTP), no `sudo`. A new option-gated NixOS module supplies system prerequisites (`usbmuxd` + MTP udev rules); the home `roles/mobile` is renamed to `roles/phone` and installs the package. `phone-tools` is fully decoupled from `media-tools` — organizing pulled files into the library is a separate `media-import` step the user composes.

**Tech Stack:** Nix (snowfall-lib, `stdenvNoCC.mkDerivation`, `makeWrapper`), Bash, FUSE (`ifuse`, `android-file-transfer`/`aft-mtp-mount`, `fusermount` security wrapper), `libimobiledevice`, `rsync`.

**Spec:** `docs/specs/2026-08-09-phone-tools-design.md`

---

## File Structure

**Package (`packages/phone-tools/`):**
- `default.nix` — derivation; installs scripts + `phone-common.sh`, wraps with runtime deps (NOT `fuse`/`exiftool`).
- `phone-common.sh` — shared lib: `MOUNT_POINT` resolution, device detection (`detect_device`), mount-state guards (`is_mounted`, `require_mounted`, `wait_for_mount`), DCIM discovery (`find_dcim`), DEST default (`default_dest`), gvfs-conflict detection, `usbmuxd` socket check, `print_info`/`print_error`, `confirm`.
- `phone-mount.sh` — detect + mount + readiness poll.
- `phone-unmount.sh` — `fusermount -u`.
- `phone-pull.sh` — rsync DCIM (or `--from`) → local DEST.
- `phone-clean.sh` — confirm-gated delete of DCIM (iOS shows AFC caveat).
- `phone-backup.sh` — mount → pull → unmount (trap unmounts only if we mounted).
- `test/run-tests.sh` — pure-logic unit tests (self-contained, mirrors media-tools test runner).

**Modules:**
- Rename `modules/home/roles/mobile/` → `modules/home/roles/phone/` (option `roles.phone`, installs `pkgs.${namespace}.phone-tools`).
- Create `modules/nixos/hardware/phone/default.nix` (option `hardware.phone.enable`; `usbmuxd` + udev rules).
- Modify `modules/home/roles/desktop/default.nix` — `roles.mobile = enabled` → `roles.phone = enabled`.
- Modify `modules/nixos/roles/desktop/default.nix` — add `hardware.phone = enabled`.

**Conventions to follow (from `packages/media-tools/`):**
- Scripts start with `set -euo pipefail` and `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`, then `source "$SCRIPT_DIR/phone-common.sh"`.
- `default.nix` uses `substituteInPlace` to repoint `SCRIPT_DIR` to `$out/lib/phone-tools`, then `wrapProgram --prefix PATH`.
- `print_info` prints `:: msg`; `print_error` prints `ERROR: msg` to stderr.
- Test runner is a standalone bash script sourcing the common lib and using `assert_eq`.

---

## Task 1: Package skeleton + `phone-common.sh` pure helpers (TDD)

Build the shared library first, driven by the pure-logic tests, so mount code can rely on tested helpers.

**Files:**
- Create: `packages/phone-tools/phone-common.sh`
- Create: `packages/phone-tools/test/run-tests.sh`

- [ ] **Step 1: Write the failing test runner** with cases for the pure helpers.

Create `packages/phone-tools/test/run-tests.sh` (mirror `packages/media-tools/test/run-tests.sh` structure: `assert_eq`, `PASS`/`FAIL`, `finish`). Source the lib:
```bash
#!/usr/bin/env bash
set -uo pipefail
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$TEST_DIR/.." && pwd)"
# shellcheck source=../phone-common.sh
source "$LIB_DIR/phone-common.sh"
```
Assertions:
```bash
# MOUNT_POINT resolution
( PHONE_MOUNT=/tmp/pp; assert_eq "PHONE_MOUNT wins" "/tmp/pp" "$(resolve_mount_point)" )
( unset PHONE_MOUNT; XDG_RUNTIME_DIR=/run/user/1000; \
  assert_eq "XDG fallback" "/run/user/1000/phone" "$(resolve_mount_point)" )
( unset PHONE_MOUNT XDG_RUNTIME_DIR; \
  assert_eq "uid fallback" "/run/user/$(id -u)/phone" "$(resolve_mount_point)" )

# default_dest <device> <yyyymmdd>
assert_eq "dest ios"     "$HOME/Phone/ios-20260809"     "$(default_dest ios 20260809)"
assert_eq "dest android" "$HOME/Phone/android-20260809" "$(default_dest android 20260809)"

# find_dcim against a fake mount tree (depth-bounded)
FAKE="$(mktemp -d)"
mkdir -p "$FAKE/DCIM/100APPLE" \
         "$FAKE/Internal storage/DCIM/Camera" \
         "$FAKE/too/deep/a/b/DCIM"
mapfile -t got < <(find_dcim "$FAKE" | sort)
assert_eq "find_dcim count (depth<=4, excludes deep)" "2" "${#got[@]}"
rm -rf "$FAKE"
```
Run: `bash packages/phone-tools/test/run-tests.sh`
Expected: FAIL — `resolve_mount_point: command not found` (lib not written yet).

- [ ] **Step 2: Write `phone-common.sh` with the pure helpers.**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Resolve the FUSE mount point. Override with PHONE_MOUNT.
resolve_mount_point() {
  echo "${PHONE_MOUNT:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/phone}"
}

# Default pull destination: ~/Phone/<device>-<yyyymmdd>
default_dest() {
  local device="$1" date="$2"
  echo "$HOME/Phone/${device}-${date}"
}

# Find DCIM directories under a mount root (depth-bounded; internal + SD).
find_dcim() {
  local root="$1"
  find "$root" -maxdepth 4 -type d -iname DCIM 2>/dev/null
}

print_error() { echo "ERROR: $1" >&2; }
print_info()  { echo ":: $1"; }
```
(Leave mount/detection helpers for later tasks — this task only needs the pure ones to pass.)

- [ ] **Step 3: Run the test to verify it passes.**

Run: `bash packages/phone-tools/test/run-tests.sh`
Expected: PASS on all assertions; `finish` returns 0.

- [ ] **Step 4: Commit.**

```bash
git add packages/phone-tools/phone-common.sh packages/phone-tools/test/run-tests.sh
git commit -m "feat(phone-tools): add phone-common pure helpers with tests"
```

---

## Task 2: Device detection + mount-state helpers (TDD where pure)

**Files:**
- Modify: `packages/phone-tools/phone-common.sh`
- Modify: `packages/phone-tools/test/run-tests.sh`

- [ ] **Step 1: Add tests for the injectable detection logic.**

Detection must be testable without hardware. Implement it as a pure function over injectable inputs, plus a thin wrapper that calls the real tools. Add to the test runner:
```bash
# classify_device <usbmuxd_socket_present:0|1> <idevice_ids> <explicit_override>
assert_eq "explicit ios"        "ios"          "$(classify_device 1 ""   ios)"
assert_eq "explicit android"    "android"      "$(classify_device 0 ""   android)"
assert_eq "ios when listed"     "ios"          "$(classify_device 1 "ab" "")"
assert_eq "android when none"   "android"      "$(classify_device 1 ""   "")"
assert_eq "iphone-no-usbmuxd"   "ios-nomuxd"   "$(classify_device 0 ""   ios)"
```
The `ios-nomuxd` sentinel lets `phone-mount` emit the "enable hardware.phone" hint when the socket is absent but the user explicitly asked for iOS (or an iPhone is attached but undetectable). Adjust the exact contract to what the assertions above encode.

Run: `bash packages/phone-tools/test/run-tests.sh`
Expected: FAIL — `classify_device: command not found`.

- [ ] **Step 2: Implement `classify_device` (pure) + real-tool wrappers in `phone-common.sh`.**

```bash
# Pure decision function. Args:
#   $1 usbmuxd_socket_present (1|0), $2 idevice_ids (may be empty), $3 override (ios|android|"")
classify_device() {
  local muxd="$1" ids="$2" override="$3"
  case "$override" in
    android) echo android; return 0 ;;
    ios)     [[ "$muxd" == 1 ]] && echo ios || echo ios-nomuxd; return 0 ;;
  esac
  if [[ "$muxd" == 1 && -n "$ids" ]]; then echo ios; else echo android; fi
}

# usbmuxd is socket-activated: test the socket, not a process.
usbmuxd_present() { [[ -S /var/run/usbmuxd || -S /run/usbmuxd ]] && echo 1 || echo 0; }

# Thin wrapper used by scripts (not unit-tested).
detect_device() { # $1 = override ("" | ios | android)
  classify_device "$(usbmuxd_present)" "$(idevice_id -l 2>/dev/null | tr '\n' ' ')" "${1:-}"
}

is_mounted() { mountpoint -q "$1"; }

# Unmount a FUSE mount. Android (aft-mtp-mount) is fuse3 -> fusermount3;
# iOS (ifuse) is fuse2 -> fusermount. Both setuid wrappers live on
# /run/wrappers/bin; try fuse3 first, fall back to fuse2.
fuse_unmount() { fusermount3 -u "$1" 2>/dev/null || fusermount -u "$1"; }

# Poll until the mount is ready (or fail). $1 = mountpoint, $2 = timeout secs.
wait_for_mount() {
  local mp="$1" timeout="${2:-10}" i=0
  while (( i < timeout )); do is_mounted "$mp" && return 0; sleep 1; i=$((i+1)); done
  return 1
}

# gvfs auto-mount holds MTP's single initiator slot on GNOME.
gvfs_mtp_active() {
  compgen -G "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/gvfs/mtp:*" >/dev/null 2>&1
}

confirm() { # $1 = prompt; returns 0 on y/Y
  local ans; read -r -p "$1 [y/N] " ans; [[ "$ans" =~ ^[Yy]$ ]]
}
```

- [ ] **Step 3: Run the test to verify it passes.**

Run: `bash packages/phone-tools/test/run-tests.sh`
Expected: PASS.

- [ ] **Step 4: Commit.**

```bash
git add packages/phone-tools/phone-common.sh packages/phone-tools/test/run-tests.sh
git commit -m "feat(phone-tools): add device detection and mount-state helpers"
```

---

## Task 3: `phone-mount` + `phone-unmount` scripts

Mounting can't be unit-tested (needs hardware); verify with `bash -n` syntax + shellcheck, and a manual checklist. Keep all decision logic in tested helpers.

**Files:**
- Create: `packages/phone-tools/phone-mount.sh`
- Create: `packages/phone-tools/phone-unmount.sh`

- [ ] **Step 1: Write `phone-mount.sh`.**

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=phone-common.sh
source "$SCRIPT_DIR/phone-common.sh"

MP="$(resolve_mount_point)"
override="${1:-}"

if is_mounted "$MP"; then print_info "Already mounted at $MP"; exit 0; fi
mkdir -p "$MP"
if [[ -n "$(ls -A "$MP" 2>/dev/null)" ]]; then
  print_error "Mount point $MP is not empty; refusing to mount over it."; exit 1
fi

device="$(detect_device "$override")"
case "$device" in
  ios-nomuxd)
    print_error "iPhone requested but usbmuxd socket not found."
    print_error "Enable it on this host: nix-config.hardware.phone.enable = true"; exit 1 ;;
  ios)
    idevicepair pair || { print_error "Pairing failed — unlock the iPhone and tap Trust."; exit 1; }
    ifuse "$MP" ;;
  android)
    if gvfs_mtp_active; then
      print_error "GNOME (gvfs) already mounted the phone over MTP, blocking access."
      print_error "Eject it first (Files → eject, or: gio mount -u <mtp-uri>) then retry."; exit 1
    fi
    print_info "If nothing mounts: unlock the phone and select 'File Transfer / MTP' mode."
    aft-mtp-mount "$MP" ;;
esac

if ! wait_for_mount "$MP" 10; then
  # Auto-detected android but the socket is absent -> an attached iPhone would
  # have fallen through to MTP. Give the targeted hint instead of a bare timeout.
  if [[ "$device" == android && "$(usbmuxd_present)" == 0 ]]; then
    print_error "If this is an iPhone: usbmuxd is not running on this host."
    print_error "Enable it: nix-config.hardware.phone.enable = true"
  fi
  print_error "Mount did not become ready at $MP within timeout."; exit 1
fi
print_info "Mounted $device at $MP"
```

- [ ] **Step 2: Write `phone-unmount.sh`.**

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=phone-common.sh
source "$SCRIPT_DIR/phone-common.sh"

MP="$(resolve_mount_point)"
if ! is_mounted "$MP"; then print_info "Nothing mounted at $MP"; exit 0; fi
fuse_unmount "$MP"
print_info "Unmounted $MP"
```

- [ ] **Step 3: Syntax + lint check.**

Run: `bash -n packages/phone-tools/phone-mount.sh && bash -n packages/phone-tools/phone-unmount.sh`
Run: `nix shell nixpkgs#shellcheck --command shellcheck -x packages/phone-tools/phone-mount.sh packages/phone-tools/phone-unmount.sh`
Expected: no syntax errors; shellcheck clean (or only intentional, annotated disables).

- [ ] **Step 4: Commit.**

```bash
git add packages/phone-tools/phone-mount.sh packages/phone-tools/phone-unmount.sh
git commit -m "feat(phone-tools): add phone-mount and phone-unmount"
```

---

## Task 4: `phone-pull` script

**Files:**
- Create: `packages/phone-tools/phone-pull.sh`
- Modify: `packages/phone-tools/test/run-tests.sh` (add `--from` / arg-parse test if logic is factored into a pure helper)

- [ ] **Step 1: Write `phone-pull.sh`.**

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=phone-common.sh
source "$SCRIPT_DIR/phone-common.sh"

MP="$(resolve_mount_point)"
DEST=""; FROM=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from) FROM="$2"; shift 2 ;;
    -*) print_error "Unknown option: $1"; exit 1 ;;
    *) DEST="$1"; shift ;;
  esac
done

if ! is_mounted "$MP"; then
  print_error "No phone mounted at $MP. Run phone-mount first."; exit 1
fi

device="$(detect_device "")"; [[ "$device" == ios* ]] && device=ios || device=android
if [[ -z "$DEST" ]]; then DEST="$(default_dest "$device" "$(date +%Y%m%d)")"; fi
mkdir -p "$DEST"

rsync_media() { # $1 = source dir
  rsync -rt --info=progress2 --no-perms --no-owner --no-group --size-only "$1" "$DEST/"
}

if [[ -n "$FROM" ]]; then
  src="$MP/$FROM"
  [[ -d "$src" ]] || { print_error "Not found on device: $FROM"; exit 1; }
  print_info "Pulling $src -> $DEST"
  rsync_media "$src"
else
  mapfile -t dcims < <(find_dcim "$MP")
  if [[ ${#dcims[@]} -eq 0 ]]; then print_info "No DCIM found under $MP; nothing to pull."; exit 0; fi
  for d in "${dcims[@]}"; do
    print_info "Pulling $d -> $DEST"
    rsync_media "$d"
  done
fi
print_info "Done. Files in $DEST"
```
Note the trailing `/` on the rsync source in `rsync_media` is intentionally absent so the `DCIM` (or `<FROM>`) directory name is preserved under `DEST`.

- [ ] **Step 2: Syntax + lint check.**

Run: `bash -n packages/phone-tools/phone-pull.sh`
Run: `nix shell nixpkgs#shellcheck --command shellcheck -x packages/phone-tools/phone-pull.sh`
Expected: clean.

- [ ] **Step 3: Commit.**

```bash
git add packages/phone-tools/phone-pull.sh packages/phone-tools/test/run-tests.sh
git commit -m "feat(phone-tools): add phone-pull"
```

---

## Task 5: `phone-clean` + `phone-backup` scripts

**Files:**
- Create: `packages/phone-tools/phone-clean.sh`
- Create: `packages/phone-tools/phone-backup.sh`

- [ ] **Step 1: Write `phone-clean.sh`** (both device types; iOS shows AFC caveat).

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=phone-common.sh
source "$SCRIPT_DIR/phone-common.sh"

MP="$(resolve_mount_point)"; FROM=""
while [[ $# -gt 0 ]]; do
  case "$1" in --from) FROM="$2"; shift 2 ;; *) print_error "Unknown option: $1"; exit 1 ;; esac
done
is_mounted "$MP" || { print_error "No phone mounted at $MP. Run phone-mount first."; exit 1; }

device="$(detect_device "")"; [[ "$device" == ios* ]] && device=ios || device=android

if [[ -n "$FROM" ]]; then targets=("$MP/$FROM"); else mapfile -t targets < <(find_dcim "$MP"); fi
[[ ${#targets[@]} -gt 0 ]] || { print_info "Nothing to clean."; exit 0; }

count=0
for t in "${targets[@]}"; do
  print_info "Target: $t"
  count=$((count + $(find "$t" -type f 2>/dev/null | wc -l)))
done
print_info "$count file(s) will be deleted."
if [[ "$device" == ios ]]; then
  print_info "iPhone note: AFC deletion does not update the Photos DB — it may orphan"
  print_info "thumbnails / leave 'Recently Deleted' entries. Prefer the Photos app if unsure."
fi
confirm "Delete the above?" || { print_info "Aborted."; exit 0; }
for t in "${targets[@]}"; do find "$t" -type f -delete 2>/dev/null || true; done
print_info "Deleted $count file(s)."
```

- [ ] **Step 2: Write `phone-backup.sh`** (mount → pull → unmount; trap unmounts only if we mounted).

This is the **final** form — do not use `$SCRIPT_DIR/phone-*.sh`. After the
derivation's `substituteInPlace`, `SCRIPT_DIR` points at `$out/lib/phone-tools`,
which holds only `phone-common.sh`. The sibling tools are on `PATH` (wrapped),
so call them **by name**. `phone-backup` parses its own optional `DEST` so it is
never mistaken for `phone-mount`'s `ios|android` override.

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=phone-common.sh
source "$SCRIPT_DIR/phone-common.sh"

DEST="${1:-}"   # optional; phone-pull applies the default if empty

MP="$(resolve_mount_point)"
WE_MOUNTED=0
cleanup() { if [[ "$WE_MOUNTED" == 1 ]] && is_mounted "$MP"; then fuse_unmount "$MP"; fi; }
trap cleanup EXIT

if ! is_mounted "$MP"; then
  phone-mount           # detects device; prints guidance on failure
  WE_MOUNTED=1
fi

if [[ -n "$DEST" ]]; then phone-pull "$DEST"; else phone-pull; fi
```

- [ ] **Step 3: Syntax + lint check.**

Run: `bash -n packages/phone-tools/phone-clean.sh && bash -n packages/phone-tools/phone-backup.sh`
Run: `nix shell nixpkgs#shellcheck --command shellcheck -x packages/phone-tools/phone-clean.sh packages/phone-tools/phone-backup.sh`
Expected: clean.

- [ ] **Step 4: Commit.**

```bash
git add packages/phone-tools/phone-clean.sh packages/phone-tools/phone-backup.sh
git commit -m "feat(phone-tools): add phone-clean and phone-backup"
```

---

## Task 6: Package `default.nix`

**Files:**
- Create: `packages/phone-tools/default.nix`

- [ ] **Step 1: Write `default.nix`** (mirror `packages/media-tools/default.nix`).

```nix
{
  pkgs,
  lib,
  ...
}:
let
  runtimeDeps = with pkgs; [
    ifuse
    libimobiledevice
    android-file-transfer # provides aft-mtp-mount
    rsync
    coreutils
    findutils
    util-linux # mountpoint (NOT in coreutils)
    glib # gio (for gvfs guidance)
    # NOT fuse: fusermount must resolve to /run/wrappers/bin (setuid)
  ];
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "phone-tools";
  version = "1.0.0";
  src = ./.;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin $out/lib/phone-tools

    cp phone-common.sh $out/lib/phone-tools/

    for script in phone-mount phone-unmount phone-pull phone-clean phone-backup; do
      cp "$script.sh" "$out/bin/$script"
      chmod +x "$out/bin/$script"

      substituteInPlace "$out/bin/$script" \
        --replace-fail 'SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"' \
        'SCRIPT_DIR="${placeholder "out"}/lib/phone-tools"'

      # $out/bin on PATH so phone-backup can call phone-mount/phone-pull by name
      # regardless of the ambient profile PATH.
      wrapProgram "$out/bin/$script" \
        --prefix PATH : ${placeholder "out"}/bin \
        --prefix PATH : ${lib.makeBinPath runtimeDeps}
    done
  '';

  meta = with lib; {
    description = "CLI tools for mounting Android/iPhone and backing up the camera roll";
    platforms = platforms.linux;
  };
}
```
Note: `phone-backup` (Task 5) already calls the sibling tools by name from PATH
(not `$SCRIPT_DIR/*.sh`), so the derivation only needs to install
`phone-common.sh` into `$out/lib/phone-tools` — no further reconciliation here.

- [ ] **Step 2: Build the package.**

`phone-tools` is Linux-only, and snowfall exposes packages as
`packages.<system>.<name>` (confirmed: `packages.x86_64-linux.{media-tools,router,wallpapers}`).
On the aarch64-darwin workbook you must target the linux attr explicitly (and a
linux builder is required — run on/through a Linux host):

Run: `nix build .#packages.x86_64-linux.phone-tools --no-link`
Expected: builds; `$out/bin` contains the five commands.

- [ ] **Step 3: Smoke-test the wrapped binaries (no device).**

Run: `RESULT=$(nix build .#packages.x86_64-linux.phone-tools --print-out-paths --no-link)`
Run: `$RESULT/bin/phone-unmount` — expect `:: Nothing mounted at …`, exit 0.
Run: `$RESULT/bin/phone-mount android` on a host with no phone attached — it must fail at the *mount/timeout* stage, NOT with `aft-mtp-mount: command not found` or `mountpoint: command not found`. (Runtime deps live on each wrapper's *private* prefixed PATH, so `command -v` from an outer shell would give a false negative — exercise the wrapped script instead, or inspect `cat $RESULT/bin/phone-mount` to confirm the `--prefix PATH` entries.)
Expected: no missing-dependency (`command not found`) errors when running the wrapped scripts.

- [ ] **Step 4: Commit.**

```bash
git add packages/phone-tools/default.nix packages/phone-tools/phone-backup.sh
git commit -m "feat(phone-tools): add package derivation"
```

---

## Task 7: Rename home role `mobile` → `phone`

**Files:**
- Rename: `modules/home/roles/mobile/default.nix` → `modules/home/roles/phone/default.nix`
- Modify: `modules/home/roles/desktop/default.nix:` (`mobile = enabled` → `phone = enabled`)

- [ ] **Step 1: `git mv` the role directory.**

```bash
git mv modules/home/roles/mobile modules/home/roles/phone
```

- [ ] **Step 2: Rewrite `modules/home/roles/phone/default.nix`.**

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
  cfg = config.${namespace}.roles.phone;
in
{
  options.${namespace}.roles.phone = with types; {
    enable = mkEnableOption "Android/iPhone mount + camera-roll backup tooling";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.${namespace}.phone-tools ];
  };
}
```

- [ ] **Step 3: Update the desktop home role.**

In `modules/home/roles/desktop/default.nix`, change `mobile = enabled;` to `phone = enabled;`.

- [ ] **Step 4: Verify no stale `roles.mobile` references remain.**

Run: `grep -rn "roles.mobile\|roles/mobile\|mobile = enabled" modules homes systems`
Expected: no matches.

- [ ] **Step 5: Commit.**

```bash
git add -A modules/home/roles
git commit -m "refactor(phone): rename home role mobile -> phone, install phone-tools"
```

---

## Task 8: NixOS `hardware/phone` module + desktop wiring

**Files:**
- Create: `modules/nixos/hardware/phone/default.nix`
- Modify: `modules/nixos/roles/desktop/default.nix` (add `hardware.phone = enabled`)

- [ ] **Step 1: Write `modules/nixos/hardware/phone/default.nix`.**

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
  cfg = config.${namespace}.hardware.phone;
in
{
  options.${namespace}.hardware.phone = {
    enable = mkBoolOpt false "USB phone integration (usbmuxd for iOS, MTP udev rules for Android)";
  };

  config = mkIf cfg.enable {
    services.usbmuxd.enable = true;
    # libmtp ships the MTP uaccess udev rules. (android-udev-rules was removed
    # from nixpkgs — superseded by built-in systemd uaccess rules.)
    services.udev.packages = [ pkgs.libmtp ];
  };
}
```

- [ ] **Step 2: Wire into the NixOS desktop role.**

In `modules/nixos/roles/desktop/default.nix`, under `config.${namespace}`, add `hardware.phone = enabled;` (alongside the existing `roles`/`services` blocks). Follow the file's existing structure.

- [ ] **Step 3: Evaluate the module.**

Run: `nix eval .#nixosConfigurations.desktop.config.nix-config.hardware.phone.enable`
Expected: `true`.
Run: `nix eval .#nixosConfigurations.desktop.config.services.usbmuxd.enable`
Expected: `true`.

- [ ] **Step 4: Commit.**

```bash
git add modules/nixos/hardware/phone/default.nix modules/nixos/roles/desktop/default.nix
git commit -m "feat(phone): add hardware.phone NixOS module, enable on desktop"
```

---

## Task 9: Full validation + docs

**Files:**
- Modify: `docs/architecture.md` and/or `docs/homelab.md` if they enumerate roles/packages (check first; only if such a list exists).

- [ ] **Step 1: Run the package unit tests.**

Run: `nix shell nixpkgs#coreutils nixpkgs#findutils --command bash packages/phone-tools/test/run-tests.sh`
Expected: all PASS, exit 0.

- [ ] **Step 2: Repo lint + format.**

Run: `just format && just lint`
Expected: no lint findings; formatting clean.

- [ ] **Step 3: Build the two affected desktop configs.** (These are x86_64-linux
closures — run on the Linux host, or via a configured linux remote builder from
the Mac.)

Run: `nix build .#nixosConfigurations.desktop.config.system.build.toplevel --no-link`
Run: `nix build .#homeConfigurations."alexander@desktop".activationPackage --no-link` (adjust attr name via `just list-configs home`).
Expected: both build.

- [ ] **Step 4: Flake check.**

Run: `just flake-check` (or `nix flake check`).
Expected: passes.

- [ ] **Step 5: Manual hardware checklist** (record results in the PR; not CI).

  - Android: plug in, select File-Transfer mode → `phone-mount` → `phone-pull ~/Phone/test` → files present → `phone-unmount`. If GNOME grabbed it, confirm the gvfs eject hint fires.
  - iPhone: unlock + Trust → `phone-mount` → `phone-pull` → `phone-unmount`.
  - `phone-backup ~/Phone/test` end-to-end for one device.
  - Compose: `media-import --move ~/Phone/test` organizes into `$MEDIA_HOME`.

- [ ] **Step 6: Commit any doc updates.**

```bash
git add -A docs
git commit -m "docs(phone): document phone-tools usage"
```

---

## Notes for the implementer

- **Reference the existing `packages/media-tools/`** for every packaging decision — this plan mirrors it deliberately.
- **`phone-backup` calls installed commands by name** (`phone-mount`/`phone-pull` on PATH), not `$SCRIPT_DIR/*.sh`, because the derivation only installs `phone-common.sh` into `$out/lib/phone-tools`. Task 5 is already written this way — keep it.
- **Do not add `fuse`/`fusermount` to `runtimeDeps`** — it would shadow the setuid `/run/wrappers/bin` helpers and break mounting. Unmount uses `fusermount3 -u || fusermount -u` (fuse3 for Android `aft-mtp-mount`, fuse2 for iOS `ifuse`); both wrappers come from `programs.fuse.enable` (default true).
- **`android-file-transfer`** provides `aft-mtp-mount`; confirm the binary name in nixpkgs (`nix eval nixpkgs#android-file-transfer.meta` / inspect `bin/`).
- Commit after every task; keep commits conventional-commit formatted.
