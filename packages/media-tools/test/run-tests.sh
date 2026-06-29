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

# --- resolve_date (integration; needs sample files + exiftool) ---
SAMPLES="${MEDIA_TEST_SAMPLES:-$HOME/Downloads/tmp1}"
PHOTO="$SAMPLES/photo_455@21-06-2026_15-17-04.jpg"
VIDEO="$SAMPLES/IMG_3449.MOV"

if [[ -f "$PHOTO" && -f "$VIDEO" ]]; then
  WORK="$(mktemp -d)"
  trap 'rm -rf "$WORK"' EXIT
  cp "$PHOTO" "$WORK/"
  cp "$VIDEO" "$WORK/"
  # mtime-only fixture: telegram photo renamed so no pattern matches and EXIF is absent
  cp "$PHOTO" "$WORK/random_name.jpg"

  assert_eq "resolve_date: video uses EXIF" \
    "2026:06:18 18:50:10	EXIF" "$(resolve_date "$WORK/IMG_3449.MOV")"
  assert_eq "resolve_date: telegram photo uses filename" \
    "2026:06:21 15:17:04	filename" "$(resolve_date "$WORK/photo_455@21-06-2026_15-17-04.jpg")"
  # For the mtime case we only assert the source label (date == export mtime, varies)
  assert_eq "resolve_date: unmatched photo falls back to mtime" \
    "mtime" "$(resolve_date "$WORK/random_name.jpg" | cut -f2)"
else
  echo "skip - resolve_date integration (sample files not found at $SAMPLES)"
fi

finish
