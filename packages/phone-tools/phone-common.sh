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

# --- device detection ---

# Pure decision function. Args:
#   $1 usbmuxd_socket_present (1|0), $2 idevice_ids (may be empty), $3 override (ios|android|"")
# Returns: ios | android | ios-nomuxd
classify_device() {
  local muxd="$1" ids="$2" override="$3"
  case "$override" in
    android) echo android; return 0 ;;
    ios)     [[ "$muxd" == 1 ]] && echo ios || echo ios-nomuxd; return 0 ;;
  esac
  if [[ "$muxd" == 1 && -n "$ids" ]]; then echo ios; else echo android; fi
}

# usbmuxd is socket-activated: test the socket, not a process.
usbmuxd_present() { { [[ -S /var/run/usbmuxd ]] || [[ -S /run/usbmuxd ]]; } && echo 1 || echo 0; }

# Thin wrapper used by scripts (not unit-tested). $1 = override ("" | ios | android)
detect_device() {
  classify_device "$(usbmuxd_present)" "$(idevice_id -l 2>/dev/null | tr '\n' ' ')" "${1:-}"
}

# --- mount state ---

is_mounted() { mountpoint -q "$1"; }

# Unmount a FUSE mount. Android (aft-mtp-mount) is fuse3 -> fusermount3;
# iOS (ifuse) is fuse2 -> fusermount. Both setuid wrappers live on
# /run/wrappers/bin; try fuse3 first, fall back to fuse2.
fuse_unmount() { fusermount3 -u "$1" 2>/dev/null || fusermount -u "$1"; }

# Poll until the mount is ready (or fail). $1 = mountpoint, $2 = timeout secs (default 10).
wait_for_mount() {
  local mp="$1" timeout="${2:-10}" i=0
  while (( i < timeout )); do is_mounted "$mp" && return 0; sleep 1; i=$((i+1)); done
  return 1
}

# gvfs auto-mount holds MTP's single initiator slot on GNOME.
gvfs_mtp_active() {
  compgen -G "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/gvfs/mtp:*" >/dev/null 2>&1
}

# $1 = prompt; returns 0 on y/Y
confirm() { local ans; read -r -p "$1 [y/N] " ans; [[ "$ans" =~ ^[Yy]$ ]]; }
