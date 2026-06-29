# media-tools Telegram Date Recovery + media-info Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recover the Telegram post date from photo filenames during both normalize and import via a pluggable filename-pattern registry, and add a read-only `media-info <file>` inspector.

**Architecture:** All shared logic lives in `media-common.sh`. Filename date parsing becomes a declarative registry (`FILENAME_DATE_PATTERNS`) consumed by a generic loop. A single `resolve_date` helper is the one authority for the EXIF→filename→mtime precedence; both the shared `fill_missing_dates` (used by `media-normalize` and `media-import`) and the new `media-info` build on it.

**Tech Stack:** Bash 5.3, exiftool, coreutils/findutils, Nix (`stdenvNoCC.mkDerivation` + `makeWrapper`). Spec: `docs/superpowers/specs/2026-06-29-media-tools-telegram-date-design.md`.

---

## Context for the implementer

- The package is four files in `packages/media-tools/`: `media-common.sh` (shared lib, sourced by the tools), `media-normalize.sh`, `media-import.sh`, `default.nix` (installs + wraps each script with runtime deps on PATH).
- `parse_date_from_filename` (media-common.sh:13-31) currently hardcodes two regexes in an `if/elif`. Each branch reassembles `BASH_REMATCH` in its own order. Output: `YYYY:MM:DD HH:MM:SS` string, or empty on no match.
- `set_all_dates` (media-common.sh:50-76) writes DateTimeOriginal/CreateDate/ModifyDate + tz offsets, either from a literal date string or `--from-mtime`.
- `media-normalize.sh`'s `fill_missing_dates` (lines 146-185) runs EXIF→filename→mtime. `media-import.sh`'s `fill_missing_dates_for_import` (lines 45-63) is **mtime-only** and has a stale comment claiming it doesn't modify sources (it does, via `set_all_dates ... -overwrite_original`).
- **exiftool is NOT on PATH in this environment.** Run anything that needs it (tests, manual checks) inside a nix shell:
  `nix shell nixpkgs#exiftool nixpkgs#coreutils nixpkgs#findutils --command bash <cmd>`
- Two real sample files for integration checks live at `~/Downloads/tmp1/`:
  - `photo_455@21-06-2026_15-17-04.jpg` — no EXIF; post date in filename → expect `2026:06:21 15:17:04`.
  - `IMG_3449.MOV` — QuickTime CreateDate `2026:06:18 18:50:10`; no date in filename.

## File Structure

| File | Responsibility |
|------|----------------|
| `packages/media-tools/media-common.sh` | Add `FILENAME_DATE_PATTERNS` registry; rewrite `parse_date_from_filename` as a registry loop; add `resolve_date` and shared `fill_missing_dates`. |
| `packages/media-tools/media-normalize.sh` | Drop local `fill_missing_dates`; call the shared one. |
| `packages/media-tools/media-import.sh` | Replace `fill_missing_dates_for_import` with the shared `fill_missing_dates`. |
| `packages/media-tools/media-info.sh` | New read-only inspector. |
| `packages/media-tools/default.nix` | Add `media-info` to the wrap loop. |
| `packages/media-tools/test/run-tests.sh` | Self-contained bash test runner (unit + integration). |

---

## Task 1: Test runner skeleton

**Files:**
- Create: `packages/media-tools/test/run-tests.sh`

- [ ] **Step 1: Create the test runner with assertion helpers**

```bash
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

# Tests are appended below by later tasks.

finish() {
  echo "----------------------------------------"
  echo "PASS: $PASS  FAIL: $FAIL"
  [[ "$FAIL" -eq 0 ]]
}
```

- [ ] **Step 2: Make it executable and run it**

Run: `chmod +x packages/media-tools/test/run-tests.sh && nix shell nixpkgs#exiftool nixpkgs#coreutils nixpkgs#findutils --command bash packages/media-tools/test/run-tests.sh`

Expected: it sources the lib and prints `PASS: 0  FAIL: 0` (the `finish` call is added in the last step of Task 2; for now it may just exit cleanly after sourcing — if `finish` is undefined that's fine, no tests yet).

> Note: `finish` is defined but not yet called. That happens at the end of Task 2 once the first tests exist.

- [ ] **Step 3: Commit**

```bash
git add packages/media-tools/test/run-tests.sh
git commit -m "test(media-tools): add bash test runner skeleton"
```

---

## Task 2: Pluggable filename-pattern registry

Replace the hardcoded `if/elif` in `parse_date_from_filename` with a declarative registry. This is the core new logic and is pure (no exiftool), so it gets full unit-test coverage.

**Files:**
- Modify: `packages/media-tools/media-common.sh` (the `parse_date_from_filename` block, currently lines 11-31)
- Modify: `packages/media-tools/test/run-tests.sh`

- [ ] **Step 1: Write the failing tests**

Append before the `finish()` definition is called (i.e. add these test lines near the bottom of `run-tests.sh`, then add the `finish` call as the very last line):

```bash
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `nix shell nixpkgs#exiftool nixpkgs#coreutils nixpkgs#findutils --command bash packages/media-tools/test/run-tests.sh`

Expected: FAILs — `telegram day-first name` fails (current code returns empty), `viber` fails (`FILENAME_DATE_PATTERNS` is undefined, treated as empty array). The prefixed/dashed/no-match cases pass against the old code.

- [ ] **Step 3: Implement the registry + generic loop**

In `media-common.sh`, replace the whole current block (lines ~11-31, from the `# Filename date patterns...` comment through the end of `parse_date_from_filename`) with:

```bash
# Pluggable filename date-pattern registry.
# Each entry is TAB-separated: "<name>\t<ERE with 6 capture groups>\t<group-order>"
# <group-order> is 6 space-separated BASH_REMATCH indices in Y M D H Mi S order.
# Patterns are tried top to bottom; first match wins. Year-first patterns come
# before day-first ones so they are never shadowed.
# To support a new source (e.g. viber/whatsapp), append one line here — no code change.
FILENAME_DATE_PATTERNS=(
  "$(printf 'prefixed\t^(IMG_|PXL_|VID_|Screenshot_)?([0-9]{4})([0-9]{2})([0-9]{2})_([0-9]{2})([0-9]{2})([0-9]{2})\t2 3 4 5 6 7')"
  "$(printf 'dashed\t([0-9]{4})-([0-9]{2})-([0-9]{2})[_ ]([0-9]{2})[-.]([0-9]{2})[-.]([0-9]{2})\t1 2 3 4 5 6')"
  "$(printf 'telegram\t[@_]([0-9]{2})-([0-9]{2})-([0-9]{4})_([0-9]{2})-([0-9]{2})-([0-9]{2})\t3 2 1 4 5 6')"
)

# Parse a date from a filename using FILENAME_DATE_PATTERNS.
# Echoes "YYYY:MM:DD HH:MM:SS" on first match, or empty string on no match.
parse_date_from_filename() {
  local filename
  filename=$(basename "$1")
  filename="${filename%.*}"  # strip extension

  local entry name regex order
  for entry in "${FILENAME_DATE_PATTERNS[@]}"; do
    IFS=$'\t' read -r name regex order <<<"$entry"
    if [[ "$filename" =~ $regex ]]; then
      # shellcheck disable=SC2086
      set -- $order  # positional params 1..6 = group indices for Y M D H Mi S
      printf '%s:%s:%s %s:%s:%s\n' \
        "${BASH_REMATCH[$1]}" "${BASH_REMATCH[$2]}" "${BASH_REMATCH[$3]}" \
        "${BASH_REMATCH[$4]}" "${BASH_REMATCH[$5]}" "${BASH_REMATCH[$6]}"
      return 0
    fi
  done
  echo ""
}

# Echo the name of the filename-pattern that matches (or empty). Used by media-info.
filename_pattern_name() {
  local filename
  filename=$(basename "$1")
  filename="${filename%.*}"
  local entry name regex order
  for entry in "${FILENAME_DATE_PATTERNS[@]}"; do
    IFS=$'\t' read -r name regex order <<<"$entry"
    if [[ "$filename" =~ $regex ]]; then
      echo "$name"
      return 0
    fi
  done
  echo ""
}
```

> Why two functions: `parse_date_from_filename` keeps its exact existing contract (date string), and `filename_pattern_name` exposes the matched source label for `media-info` (Task 5) without changing that contract.

- [ ] **Step 4: Run tests to verify they pass**

Run: `nix shell nixpkgs#exiftool nixpkgs#coreutils nixpkgs#findutils --command bash packages/media-tools/test/run-tests.sh`

Expected: all `parse_date_from_filename` + extensibility assertions `ok`, ending `PASS: 6  FAIL: 0`.

- [ ] **Step 5: Commit**

```bash
git add packages/media-tools/media-common.sh packages/media-tools/test/run-tests.sh
git commit -m "feat(media-tools): pluggable filename date-pattern registry with telegram support"
```

---

## Task 3: `resolve_date` precedence authority

One helper encapsulating EXIF→filename→mtime precedence, returning both the date and its source. Integration-tested against the real sample files.

**Files:**
- Modify: `packages/media-tools/media-common.sh` (add after `parse_date_from_filename`/`filename_pattern_name`)
- Modify: `packages/media-tools/test/run-tests.sh`

- [ ] **Step 1: Write the failing integration tests**

Add a fixtures helper + tests to `run-tests.sh`, before the `finish` call. Guard on the sample files so the suite degrades gracefully if they're absent:

```bash
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `nix shell nixpkgs#exiftool nixpkgs#coreutils nixpkgs#findutils --command bash packages/media-tools/test/run-tests.sh`

Expected: FAIL — `resolve_date: command not found` (or empty output) for the three new assertions.

- [ ] **Step 3: Implement `resolve_date`**

Add to `media-common.sh`:

```bash
# Decide which date a file would receive and where it comes from.
# Precedence: embedded EXIF/QuickTime CreateDate -> filename pattern -> file mtime.
# Echoes TAB-separated: "<YYYY:MM:DD HH:MM:SS>\t<EXIF|filename|mtime>".
resolve_date() {
  local file="$1"

  local create_date
  create_date=$(exiftool -s3 -CreateDate "$file" 2>/dev/null || true)
  if [[ -n "$create_date" && "$create_date" != "0000:00:00 00:00:00" ]]; then
    printf '%s\t%s\n' "$create_date" "EXIF"
    return 0
  fi

  local parsed
  parsed=$(parse_date_from_filename "$file")
  if [[ -n "$parsed" ]]; then
    printf '%s\t%s\n' "$parsed" "filename"
    return 0
  fi

  local mtime_date
  mtime_date=$(exiftool -s3 -d "%Y:%m:%d %H:%M:%S" -FileModifyDate "$file" 2>/dev/null || true)
  printf '%s\t%s\n' "$mtime_date" "mtime"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `nix shell nixpkgs#exiftool nixpkgs#coreutils nixpkgs#findutils --command bash packages/media-tools/test/run-tests.sh`

Expected: the three `resolve_date` assertions `ok` (or `skip` line if samples absent — but they should be present).

- [ ] **Step 5: Commit**

```bash
git add packages/media-tools/media-common.sh packages/media-tools/test/run-tests.sh
git commit -m "feat(media-tools): add resolve_date precedence helper"
```

---

## Task 4: Shared `fill_missing_dates` in common; wire normalize

Move the fill chain into `media-common.sh`, built on `resolve_date`, and have `media-normalize` use it. Behavior must stay identical to today.

**Files:**
- Modify: `packages/media-tools/media-common.sh` (add `fill_missing_dates`)
- Modify: `packages/media-tools/media-normalize.sh` (remove local `fill_missing_dates`, lines 146-185; keep the `set_dates`/`force_set_dates` wiring)

- [ ] **Step 1: Add shared `fill_missing_dates` to `media-common.sh`**

```bash
# Fill missing CreateDate on all media files in <dir>, in place.
# Skips files that already have a valid CreateDate (EXIF source).
# Otherwise sets dates from the filename pattern, else from mtime.
# Honors DRY_RUN and RECURSIVE globals. Mutates source files (-overwrite_original).
fill_missing_dates() {
  local dir="$1"
  local find_depth=("-maxdepth" "1")
  if [[ "$RECURSIVE" == true ]]; then
    find_depth=()
  fi

  local ext file date source
  for ext in $EXTENSIONS; do
    while IFS= read -r -d '' file; do
      IFS=$'\t' read -r date source < <(resolve_date "$file")
      case "$source" in
        EXIF)
          continue ;;
        filename)
          if [[ "$DRY_RUN" == true ]]; then
            print_info "[dry-run] Set date from filename: $file -> $date"
          else
            set_all_dates "$file" "$date"
            print_info "Set date from filename: $file -> $date"
          fi ;;
        mtime)
          if [[ "$DRY_RUN" == true ]]; then
            print_info "[dry-run] Set date from mtime: $file"
          else
            set_all_dates "$file" --from-mtime
            print_info "Set date from mtime: $file"
          fi ;;
      esac
    done < <(find "$dir" "${find_depth[@]}" -iname "*.$ext" -type f -print0 2>/dev/null)
  done
}
```

> Note: the mtime branch still uses `set_all_dates --from-mtime` (not the resolved string) so the timezone-offset handling is preserved exactly as before.

- [ ] **Step 2: Remove the local copy from `media-normalize.sh`**

Delete the entire local `fill_missing_dates` function (media-normalize.sh:146-185). The `set_dates` function (line 92-100) already calls `fill_missing_dates "$dir"` — it now resolves to the shared one. Leave `force_set_dates` untouched.

- [ ] **Step 3: Verify normalize behavior on the sample photo (dry-run)**

Run:
```bash
nix shell nixpkgs#exiftool nixpkgs#coreutils nixpkgs#findutils --command bash -c '
  W=$(mktemp -d); cp ~/Downloads/tmp1/photo_455@21-06-2026_15-17-04.jpg "$W/";
  bash packages/media-tools/media-normalize.sh --dry-run "$W"'
```
Expected: a line `[dry-run] Set date from filename: .../photo_455@21-06-2026_15-17-04.jpg -> 2026:06:21 15:17:04` (NOT from mtime).

- [ ] **Step 4: Run the unit suite to confirm no regression**

Run: `nix shell nixpkgs#exiftool nixpkgs#coreutils nixpkgs#findutils --command bash packages/media-tools/test/run-tests.sh`
Expected: `FAIL: 0`.

- [ ] **Step 5: Commit**

```bash
git add packages/media-tools/media-common.sh packages/media-tools/media-normalize.sh
git commit -m "refactor(media-tools): share fill_missing_dates via resolve_date"
```

---

## Task 5: Wire `media-import` to the shared fill chain

**Files:**
- Modify: `packages/media-tools/media-import.sh` (remove `fill_missing_dates_for_import` lines 42-63; replace both call sites)

- [ ] **Step 1: Delete `fill_missing_dates_for_import`**

Remove the function (and its stale "source files are NOT modified" comment block, lines 42-63).

- [ ] **Step 2: Replace its two call sites with the shared function**

In `media-import.sh`, the `--move` branch (line ~114) and the copy branch (line ~147) each call `fill_missing_dates_for_import`. Replace both with:

```bash
  fill_missing_dates "$SRC"
```

`$SRC` is set at line 67; `DRY_RUN`/`RECURSIVE` are already in scope from `parse_common_args`. The shared function honors them.

- [ ] **Step 3: Verify import maps the sample photo to the post date (dry-run)**

> The import dry-run path uses exiftool's own `-p` mapping from `$CreateDate` and does not call `fill_missing_dates`, so to verify the fallback you check the non-dry copy path on a throwaway dir, or confirm via `resolve_date`. Use this end-to-end check:

```bash
nix shell nixpkgs#exiftool nixpkgs#coreutils nixpkgs#findutils --command bash -c '
  set -e
  SRC=$(mktemp -d); DST=$(mktemp -d)
  cp ~/Downloads/tmp1/photo_455@21-06-2026_15-17-04.jpg "$SRC/"
  MEDIA_HOME="$DST" bash packages/media-tools/media-import.sh "$SRC"
  echo "--- result tree ---"; find "$DST" -type f'
```
Expected: the file lands at `$DST/All/2026/06/20260621_151704.jpg` (post date), not under `2026/06/29`.

- [ ] **Step 4: Run the unit suite**

Run: `nix shell nixpkgs#exiftool nixpkgs#coreutils nixpkgs#findutils --command bash packages/media-tools/test/run-tests.sh`
Expected: `FAIL: 0`.

- [ ] **Step 5: Commit**

```bash
git add packages/media-tools/media-import.sh
git commit -m "fix(media-tools): import recovers telegram post dates via shared fill chain"
```

---

## Task 6: New `media-info` inspector

**Files:**
- Create: `packages/media-tools/media-info.sh`
- Modify: `packages/media-tools/test/run-tests.sh`

- [ ] **Step 1: Write the failing integration test**

Add to `run-tests.sh` **inside the existing `if [[ -f "$PHOTO" && -f "$VIDEO" ]]` block from Task 3** (do NOT open a new block — `$WORK` and the copied fixtures are defined only inside that block; a separate `if` would leave `$WORK` unbound and fail under `set -u`):

```bash
  # (these lines go inside Task 3's `if [[ -f "$PHOTO" && -f "$VIDEO" ]]` block,
  #  after the resolve_date assertions, so $WORK is in scope)
  info_out="$(bash "$LIB_DIR/media-info.sh" "$WORK/photo_455@21-06-2026_15-17-04.jpg")"
  assert_eq "media-info resolved source is filename" \
    "1" "$(grep -c 'source: filename' <<<"$info_out")"
  assert_eq "media-info would-become name is post date" \
    "1" "$(grep -c '20260621_151704.jpg' <<<"$info_out")"
```

- [ ] **Step 2: Run to verify failure**

Run: `nix shell nixpkgs#exiftool nixpkgs#coreutils nixpkgs#findutils --command bash packages/media-tools/test/run-tests.sh`
Expected: FAIL — `media-info.sh` does not exist yet.

- [ ] **Step 3: Implement `media-info.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=media-common.sh
source "$SCRIPT_DIR/media-common.sh"

usage() {
  cat <<EOF
Usage: media-info FILE [FILE...]

Show how each file's date would be resolved (EXIF -> filename -> mtime) before
normalizing or importing. Read-only: modifies nothing.
EOF
}

if [[ $# -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  [[ $# -eq 0 ]] && exit 1 || exit 0
fi

inspect() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    print_error "Not a file: $file"
    return 1
  fi

  local create_date modify_date fs_date parsed pname resolved date source ext base
  create_date=$(exiftool -s3 -CreateDate "$file" 2>/dev/null || true)
  modify_date=$(exiftool -s3 -ModifyDate "$file" 2>/dev/null || true)
  fs_date=$(exiftool -s3 -d "%Y:%m:%d %H:%M:%S" -FileModifyDate "$file" 2>/dev/null || true)
  parsed=$(parse_date_from_filename "$file")
  pname=$(filename_pattern_name "$file")

  IFS=$'\t' read -r date source < <(resolve_date "$file")

  ext="${file##*.}"
  ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
  # canonical name from resolved date (YYYY:MM:DD HH:MM:SS -> YYYYMMDD_HHMMSS)
  base=$(echo "$date" | sed -E 's/[: ]//g')        # YYYYMMDDHHMMSS
  base="${base:0:8}_${base:8:6}"

  echo "$file"
  printf '  EXIF CreateDate : %s\n' "${create_date:-(none)}"
  printf '  EXIF ModifyDate : %s\n' "${modify_date:-(none)}"
  printf '  FileModifyDate  : %s\n' "${fs_date:-(none)}"
  if [[ -n "$parsed" ]]; then
    printf '  Filename parse  : %s   (%s)\n' "$parsed" "$pname"
  else
    printf '  Filename parse  : (no match)\n'
  fi
  printf '  -> Resolved     : %s   [source: %s]\n' "$date" "$source"
  printf '  -> Would become : %s.%s\n' "$base" "$ext"
  echo ""
}

rc=0
for f in "$@"; do
  inspect "$f" || rc=1
done
exit "$rc"
```

- [ ] **Step 4: Run to verify pass + eyeball both samples**

Run: `nix shell nixpkgs#exiftool nixpkgs#coreutils nixpkgs#findutils --command bash packages/media-tools/test/run-tests.sh`
Expected: media-info assertions `ok`, `FAIL: 0`.

Then eyeball both samples:
```bash
nix shell nixpkgs#exiftool nixpkgs#coreutils nixpkgs#findutils --command bash -c '
  bash packages/media-tools/media-info.sh \
    ~/Downloads/tmp1/photo_455@21-06-2026_15-17-04.jpg \
    ~/Downloads/tmp1/IMG_3449.MOV'
```
Expected: photo → `source: filename`, `20260621_151704.jpg`; video → `source: EXIF`, `20260618_185010.mov`.

- [ ] **Step 5: Commit**

```bash
git add packages/media-tools/media-info.sh packages/media-tools/test/run-tests.sh
git commit -m "feat(media-tools): add read-only media-info inspector"
```

---

## Task 7: Package `media-info` + full validation

**Files:**
- Modify: `packages/media-tools/default.nix` (line 27 loop)

- [ ] **Step 1: Add `media-info` to the wrap loop**

In `default.nix`, change:

```nix
    for script in media-normalize media-import; do
```
to:
```nix
    for script in media-normalize media-import media-info; do
```

The existing `substituteInPlace` (SCRIPT_DIR patch) and `wrapProgram` (PATH prefix) then apply to `media-info` automatically.

- [ ] **Step 2: Build the package**

Run: `nix build .#packages.aarch64-darwin.media-tools` (the package is snowfall-namespaced; the bare `.#media-tools` attr will NOT resolve). If the attr path differs, discover it via `nix eval --json .#packages.aarch64-darwin --apply builtins.attrNames 2>/dev/null`.
Expected: build succeeds; `result/bin/` contains `media-info`, `media-normalize`, `media-import`.

- [ ] **Step 3: Run the wrapped binary (deps on PATH, no nix shell needed)**

Run: `./result/bin/media-info ~/Downloads/tmp1/photo_455@21-06-2026_15-17-04.jpg`
Expected: same output as Task 6 Step 4 — confirms wrapping put exiftool on PATH and the SCRIPT_DIR patch resolved `media-common.sh`.

- [ ] **Step 4: Lint + format**

Run: `just lint && just format-check`
Expected: clean. If shellcheck flags the new scripts, fix and re-run. (Common: `SC2086` on intentional word-splitting already has `# shellcheck disable` in the existing code — follow that pattern.)

- [ ] **Step 5: Full test suite final pass**

Run: `nix shell nixpkgs#exiftool nixpkgs#coreutils nixpkgs#findutils --command bash packages/media-tools/test/run-tests.sh`
Expected: `FAIL: 0`.

- [ ] **Step 6: Commit**

```bash
git add packages/media-tools/default.nix
git commit -m "build(media-tools): package media-info binary"
```

---

## Done criteria

- `media-info <photo>` reports `source: filename` and the post-date name; `<video>` reports `source: EXIF`.
- `media-normalize` and `media-import` both recover Telegram post dates for the sample photo; video keeps its capture date.
- Adding a new format is a single line appended to `FILENAME_DATE_PATTERNS`.
- `run-tests.sh` is green; `just lint`/`format-check` clean; `nix build .#media-tools` succeeds.
