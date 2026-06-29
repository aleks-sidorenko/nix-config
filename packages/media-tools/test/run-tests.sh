#!/usr/bin/env bash
# Self-contained test runner for media-tools.
# Run inside a nix shell that provides exiftool + coreutils + findutils:
#   nix shell nixpkgs#exiftool nixpkgs#coreutils nixpkgs#findutils \
#     --command bash packages/media-tools/test/run-tests.sh
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$TEST_DIR/.." && pwd)"
# shellcheck source=../media-common.sh
source "$LIB_DIR/media-common.sh"

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

# --- parse_date_from_filename (registry) ---
assert_eq "prefixed IMG_ name" \
  "2023:01:15 14:30:00" "$(parse_date_from_filename 'IMG_20230115_143000.jpg')"
assert_eq "bare YYYYMMDD_HHMMSS name" \
  "2023:01:15 14:30:00" "$(parse_date_from_filename '20230115_143000.jpg')"
assert_eq "dashed ISO name" \
  "2023:01:15 14:30:00" "$(parse_date_from_filename '2023-01-15_14-30-00.jpg')"
assert_eq "telegram day-first name" \
  "2026:06:21 15:17:04" "$(parse_date_from_filename 'photo_455@21-06-2026_15-17-04.jpg')"
assert_eq "no-match name returns empty" \
  "" "$(parse_date_from_filename 'random_file.jpg')"

# --- extensibility: appending one registry entry is enough ---
FILENAME_DATE_PATTERNS+=(
  "$(printf 'viber\tviber_image_([0-9]{4})-([0-9]{2})-([0-9]{2})-([0-9]{2})-([0-9]{2})-([0-9]{2})\t1 2 3 4 5 6')"
)
assert_eq "newly-registered viber pattern works without code change" \
  "2025:12:31 09:08:07" "$(parse_date_from_filename 'viber_image_2025-12-31-09-08-07.jpg')"

finish
