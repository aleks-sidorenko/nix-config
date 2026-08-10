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
  # The phone may have auto-locked and dropped the mount; try to (re)mount once
  # (phone-mount also clears any stale endpoint) before giving up.
  print_info "Phone not mounted at $MP; attempting to mount..."
  phone-mount || { print_error "Could not mount the phone. Run phone-mount first."; exit 1; }
fi

device="$(detect_device "")"; [[ "$device" == ios* ]] && device=ios || device=android
if [[ -z "$DEST" ]]; then DEST="$(default_dest "$device" "$(date +%Y%m%d)")"; fi
mkdir -p "$DEST"

rsync_media() { # $1 = source dir
  # Skip thumbnail caches / media-scanner markers that live inside DCIM on both
  # Android (.thumbnails, .nomedia) and iOS — they are not camera-roll media.
  rsync -rt --info=progress2 --no-perms --no-owner --no-group --size-only \
    --exclude='.thumbnails/' --exclude='.nomedia' "$1" "$DEST/"
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
