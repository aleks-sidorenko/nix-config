#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=phone-common.sh
source "$SCRIPT_DIR/phone-common.sh"

MP="$(resolve_mount_point)"
override="${1:-}"

if is_mounted "$MP"; then print_info "Already mounted at $MP"; exit 0; fi
clear_stale_mount "$MP"   # recover a dead endpoint left by a dropped connection
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
      print_error "Eject it first (Files -> eject, or: gio mount -u <mtp-uri>) then retry."; exit 1
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
