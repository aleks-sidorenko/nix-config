#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=phone-common.sh
source "$SCRIPT_DIR/phone-common.sh"

MP="$(resolve_mount_point)"
if ! is_mounted "$MP"; then print_info "Nothing mounted at $MP"; exit 0; fi
fuse_unmount "$MP"
print_info "Unmounted $MP"
