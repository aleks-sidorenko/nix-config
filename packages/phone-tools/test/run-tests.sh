#!/usr/bin/env bash
# Self-contained test runner for phone-tools (pure helpers only).
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$TEST_DIR/.." && pwd)"
# shellcheck source=../phone-common.sh
source "$LIB_DIR/phone-common.sh"

PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "ok   - $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL - $desc"
    echo "         expected: [$expected]"
    echo "         actual:   [$actual]"
    FAIL=$((FAIL + 1))
  fi
}

finish() {
  echo "----------------------------------------"
  echo "PASS: $PASS  FAIL: $FAIL"
  [[ "$FAIL" -eq 0 ]]
}

# --- resolve_mount_point (assert_eq must run in the parent so counters are real) ---
assert_eq "PHONE_MOUNT wins" "/tmp/pp" "$(PHONE_MOUNT=/tmp/pp resolve_mount_point)"
assert_eq "XDG fallback" "/run/user/1000/phone" \
  "$(unset PHONE_MOUNT; XDG_RUNTIME_DIR=/run/user/1000 resolve_mount_point)"
assert_eq "uid fallback" "/run/user/$(id -u)/phone" \
  "$(unset PHONE_MOUNT XDG_RUNTIME_DIR; resolve_mount_point)"

# --- default_dest <device> <yyyymmdd> ---
assert_eq "dest ios"     "$HOME/Phone/ios-20260809"     "$(default_dest ios 20260809)"
assert_eq "dest android" "$HOME/Phone/android-20260809" "$(default_dest android 20260809)"

# --- find_dcim against a fake mount tree (depth-bounded) ---
# Real camera rolls (/DCIM, Android /Internal storage/DCIM) should match; these
# should NOT: the too-deep DCIM (maxdepth), the iOS PhotoData/Mutations/DCIM
# (edit artifacts), and an Android app-sandbox DCIM under Android/data.
FAKE="$(mktemp -d)"
mkdir -p "$FAKE/DCIM/100APPLE" \
         "$FAKE/Internal storage/DCIM/Camera" \
         "$FAKE/PhotoData/Mutations/DCIM/100APPLE" \
         "$FAKE/Android/data/com.example/DCIM" \
         "$FAKE/too/deep/a/b/DCIM"
mapfile -t got < <(find_dcim "$FAKE" | sort)
assert_eq "find_dcim count (real camera rolls only)" "2" "${#got[@]}"
assert_eq "find_dcim excludes iOS PhotoData mutations DCIM" \
  "" "$(find_dcim "$FAKE" | grep PhotoData || true)"
assert_eq "find_dcim excludes Android app-sandbox DCIM" \
  "" "$(find_dcim "$FAKE" | grep '/Android/' || true)"
rm -rf "$FAKE"

# classify_device <usbmuxd_socket_present:1|0> <idevice_ids> <override:ios|android|"">
assert_eq "explicit ios"       "ios"        "$(classify_device 1 ""   ios)"
assert_eq "explicit android"   "android"    "$(classify_device 0 ""   android)"
assert_eq "ios when listed"    "ios"        "$(classify_device 1 "ab" "")"
assert_eq "android when none"  "android"    "$(classify_device 1 ""   "")"
assert_eq "iphone-no-usbmuxd"  "ios-nomuxd" "$(classify_device 0 ""   ios)"

finish
