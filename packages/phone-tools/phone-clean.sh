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
