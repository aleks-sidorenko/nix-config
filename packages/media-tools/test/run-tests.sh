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

# --- resolve_src_dest (import SRC/DEST resolution; pure, no exiftool needed) ---
# 0 args: SRC defaults to ".", DEST defaults to $MEDIA_HOME
assert_eq "resolve_src_dest: no args -> cwd + MEDIA_HOME" \
  $'.\t/home/u/Media' "$(MEDIA_HOME=/home/u/Media resolve_src_dest)"
# 1 arg: that arg is SRC, DEST still defaults to $MEDIA_HOME
assert_eq "resolve_src_dest: one arg is SRC, DEST from MEDIA_HOME" \
  $'./dump\t/home/u/Media' "$(MEDIA_HOME=/home/u/Media resolve_src_dest ./dump)"
# 2 args: explicit DEST wins over $MEDIA_HOME (cp/mv-style trailing DEST)
assert_eq "resolve_src_dest: explicit DEST overrides MEDIA_HOME" \
  $'./dump\t/mnt/usb/home/dima/Media' \
  "$(MEDIA_HOME=/home/u/Media resolve_src_dest ./dump /mnt/usb/home/dima/Media)"
# no MEDIA_HOME and no DEST arg: DEST resolves empty (caller must error)
assert_eq "resolve_src_dest: unset MEDIA_HOME yields empty DEST" \
  $'.\t' "$(MEDIA_HOME='' resolve_src_dest)"

# --- case_safe_mv (case-only rename, e.g. .MP4 -> .mp4) ---
# Must work even on case-insensitive filesystems (macOS), where a plain
# `mv x.MP4 x.mp4` fails with "are the same file".
CSM_WORK="$(mktemp -d)"
: > "$CSM_WORK/107163_IMG_4466.MP4"
csm_rc=0
case_safe_mv "$CSM_WORK/107163_IMG_4466.MP4" "$CSM_WORK/107163_IMG_4466.mp4" || csm_rc=$?
assert_eq "case_safe_mv: case-only rename succeeds" "0" "$csm_rc"
assert_eq "case_safe_mv: extension is now lowercase" \
  "107163_IMG_4466.mp4" "$(cd "$CSM_WORK" && ls)"
rm -rf "$CSM_WORK"

# --- canonical_name_from_date (pure name builder used by dry-run previews) ---
assert_eq "canonical_name_from_date: builds YYYYMMDD_HHMMSS + lowercased ext" \
  "20230115_143000.jpg" "$(canonical_name_from_date '2023:01:15 14:30:00' 'IMG_0001.JPG')"
assert_eq "canonical_name_from_date: preserves mov/mp4 lowercased" \
  "20260618_185010.mov" "$(canonical_name_from_date '2026:06:18 18:50:10' 'IMG_3449.MOV')"
assert_eq "canonical_name_from_date: empty date yields empty name" \
  "" "$(canonical_name_from_date '' 'x.jpg')"
assert_eq "canonical_name_from_date: malformed date yields empty name" \
  "" "$(canonical_name_from_date 'not-a-date' 'x.jpg')"
# EXIF CreateDate may carry a trailing timezone (macOS screenshots) or
# subseconds; the canonical name must be derived from the wall-clock portion.
assert_eq "canonical_name_from_date: tolerates trailing timezone offset" \
  "20260911_161740.png" "$(canonical_name_from_date '2026:09:11 16:17:40+03:00' 'Screenshot.PNG')"
assert_eq "canonical_name_from_date: tolerates subseconds + negative tz" \
  "20230115_143000.jpg" "$(canonical_name_from_date '2023:01:15 14:30:00.123-05:00' 'x.JPG')"

# --- unique_target (collision-safe rename target, mirrors exiftool %-c) ---
UT_WORK="$(mktemp -d)"
assert_eq "unique_target: no collision returns dir/name" \
  "$UT_WORK/20230115_143000.jpg" \
  "$(unique_target "$UT_WORK" "20230115_143000.jpg" "$UT_WORK/src.jpg")"
: > "$UT_WORK/20230115_143000.jpg"
assert_eq "unique_target: collision inserts -1 before extension" \
  "$UT_WORK/20230115_143000-1.jpg" \
  "$(unique_target "$UT_WORK" "20230115_143000.jpg" "$UT_WORK/src.jpg")"
: > "$UT_WORK/20230115_143000-1.jpg"
assert_eq "unique_target: second collision inserts -2" \
  "$UT_WORK/20230115_143000-2.jpg" \
  "$(unique_target "$UT_WORK" "20230115_143000.jpg" "$UT_WORK/src.jpg")"
assert_eq "unique_target: target that is the source stays unchanged" \
  "$UT_WORK/20230115_143000.jpg" \
  "$(unique_target "$UT_WORK" "20230115_143000.jpg" "$UT_WORK/20230115_143000.jpg")"
rm -rf "$UT_WORK"

# --- media-normalize step-3 logging + resilience ---
# A real run must log the actual normalization rename (not just the extension
# rename), and one un-taggable file must not abort the batch.
if command -v exiftool >/dev/null 2>&1; then
  RES_WORK="$(mktemp -d)"
  # Minimal valid JPEG that exiftool can write dates into; fixed mtime so its
  # canonical name is deterministic (date comes from mtime).
  base64 -d > "$RES_WORK/good.jpg" <<'EOF'
/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAMCAgICAgMCAgIDAwMDBAYEBAQEBAgGBgUGCQgKCgkI
CQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/wAALCAABAAEBAREA/8QAFAABAAAAAAAA
AAAAAAAAAAAAAv/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AfwD/2Q==
EOF
  touch -t 202101020304.05 "$RES_WORK/good.jpg"       # -> 20210102_030405.jpg
  head -c 4096 /dev/urandom > "$RES_WORK/corrupt.jpg" # exiftool cannot tag this
  touch -t 202202020000.00 "$RES_WORK/corrupt.jpg"    # different date, no collision
  res_rc=0
  res_out="$(bash "$LIB_DIR/media-normalize.sh" "$RES_WORK" 2>&1)" || res_rc=$?
  assert_eq "media-normalize: corrupt sibling does not abort the run" "0" "$res_rc"
  assert_eq "media-normalize: good file renamed to its canonical name" \
    "1" "$([[ -f "$RES_WORK/20210102_030405.jpg" ]] && echo 1 || echo 0)"
  assert_eq "media-normalize: logs the actual normalization rename" \
    "1" "$(grep -c 'Normalized:.*20210102_030405.jpg' <<<"$res_out")"
  rm -rf "$RES_WORK"
else
  echo "skip - media-normalize step-3 logging/resilience (exiftool unavailable)"
fi

# --- media-import logging (consistent with media-normalize) ---
if command -v exiftool >/dev/null 2>&1; then
  IMP_WORK="$(mktemp -d)"
  # Write a valid JPEG padded past MIN_FILE_SIZE so import selects it.
  mk_media() {
    base64 -d > "$1" <<'EOF'
/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAMCAgICAgMCAgIDAwMDBAYEBAQEBAgGBgUGCQgKCgkI
CQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/wAALCAABAAEBAREA/8QAFAABAAAAAAAA
AAAAAAAAAAAAAv/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AfwD/2Q==
EOF
    head -c 40000 /dev/zero >> "$1"
  }

  # -- copy + dry-run logging --
  IMP_SRC="$IMP_WORK/src"; IMP_DST="$IMP_WORK/lib"; mkdir -p "$IMP_SRC"
  mk_media "$IMP_SRC/IMG_20230115_143000.jpg"
  DEST_FILE="$IMP_DST/All/2023/01/20230115_143000.jpg"

  dry_out="$(bash "$LIB_DIR/media-import.sh" --dry-run "$IMP_SRC" "$IMP_DST" 2>&1)"
  assert_eq "media-import: dry-run logs '[dry-run] Imported'" \
    "1" "$(grep -c '\[dry-run\] Imported:.*20230115_143000.jpg' <<<"$dry_out")"
  assert_eq "media-import: dry-run copies no file" \
    "0" "$([[ -f "$DEST_FILE" ]] && echo 1 || echo 0)"

  imp_rc=0
  imp_out="$(bash "$LIB_DIR/media-import.sh" "$IMP_SRC" "$IMP_DST" 2>&1)" || imp_rc=$?
  assert_eq "media-import: copy exits 0" "0" "$imp_rc"
  assert_eq "media-import: real run logs 'Imported'" \
    "1" "$(grep -c 'Imported:.*20230115_143000.jpg' <<<"$imp_out")"
  assert_eq "media-import: file copied to All/YYYY/MM" \
    "1" "$([[ -f "$DEST_FILE" ]] && echo 1 || echo 0)"

  # -- move mode: source removed only after a successful copy --
  MV_SRC="$IMP_WORK/msrc"; MV_DST="$IMP_WORK/mlib"; mkdir -p "$MV_SRC"
  mk_media "$MV_SRC/IMG_20240202_120000.jpg"
  mv_rc=0
  bash "$LIB_DIR/media-import.sh" --move "$MV_SRC" "$MV_DST" >/dev/null 2>&1 || mv_rc=$?
  assert_eq "media-import: move exits 0" "0" "$mv_rc"
  assert_eq "media-import: move copies to dest" \
    "1" "$([[ -f "$MV_DST/All/2024/02/20240202_120000.jpg" ]] && echo 1 || echo 0)"
  assert_eq "media-import: move deletes source" \
    "0" "$([[ -f "$MV_SRC/IMG_20240202_120000.jpg" ]] && echo 1 || echo 0)"

  # -- --recursive descends into subdirectories --
  RC_SRC="$IMP_WORK/rsrc"; RC_DST="$IMP_WORK/rlib"; mkdir -p "$RC_SRC/sub"
  mk_media "$RC_SRC/sub/IMG_20250303_090000.jpg"
  bash "$LIB_DIR/media-import.sh" --recursive "$RC_SRC" "$RC_DST" >/dev/null 2>&1
  assert_eq "media-import: --recursive imports nested files" \
    "1" "$([[ -f "$RC_DST/All/2025/03/20250303_090000.jpg" ]] && echo 1 || echo 0)"

  rm -rf "$IMP_WORK"
else
  echo "skip - media-import logging (exiftool unavailable)"
fi

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
  assert_eq "resolve_date: missing file returns non-zero" \
    "1" "$(resolve_date "$WORK/does_not_exist.jpg" >/dev/null 2>&1; echo $?)"

  # --- media-info (integration) ---
  info_out="$(bash "$LIB_DIR/media-info.sh" "$WORK/photo_455@21-06-2026_15-17-04.jpg")"
  assert_eq "media-info resolved source is filename" \
    "1" "$(grep -c 'source: filename' <<<"$info_out")"
  assert_eq "media-info would-become name is post date" \
    "1" "$(grep -c '20260621_151704.jpg' <<<"$info_out")"
else
  echo "skip - resolve_date integration (sample files not found at $SAMPLES)"
fi

finish
