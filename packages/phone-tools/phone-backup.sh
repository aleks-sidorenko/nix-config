#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=phone-common.sh
source "$SCRIPT_DIR/phone-common.sh"

DEST="${1:-}"   # optional; phone-pull applies the default if empty

MP="$(resolve_mount_point)"
WE_MOUNTED=0
# shellcheck disable=SC2317  # invoked via trap, not a direct call
cleanup() { if [[ "$WE_MOUNTED" == 1 ]] && is_mounted "$MP"; then fuse_unmount "$MP"; fi; }
trap cleanup EXIT

if ! is_mounted "$MP"; then
  phone-mount           # detects device; prints guidance on failure
  WE_MOUNTED=1
fi

if [[ -n "$DEST" ]]; then phone-pull "$DEST"; else phone-pull; fi
