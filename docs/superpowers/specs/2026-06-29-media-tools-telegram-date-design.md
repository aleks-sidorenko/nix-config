# Design: Telegram post-date recovery and a `media-info` inspector for media-tools

**Date:** 2026-06-29
**Status:** Approved (design)
**Component:** `packages/media-tools/`

## Problem

Media exported from Telegram channels imports with the wrong date.

- **Photos:** Telegram strips all EXIF/metadata. The only embedded date carrier is the
  filename, which uses a day-first format:
  `photo_<id>@DD-MM-YYYY_HH-MM-SS.jpg` (e.g. `photo_455@21-06-2026_15-17-04.jpg` =
  posted 2026-06-21 15:17:04). The current `parse_date_from_filename` only recognizes
  `YYYYMMDD_HHMMSS` and ISO `YYYY-MM-DD` shapes, so the Telegram name does **not** match
  and the tool falls through to the file modification time — which is the export/download
  date (today), not the post date. **This is the reported bug.**
- **Videos:** Telegram preserves QuickTime metadata. `IMG_3449.MOV` carries
  `QuickTime:CreateDate = 2026:06:18 18:50:10` (real capture date), so videos already
  import correctly via the existing EXIF-first precedence. No change needed for videos.

Two structural issues compound the bug:

1. `media-normalize` resolves missing dates via the chain EXIF → filename → mtime, but
   `media-import` has a separate `fill_missing_dates_for_import` that fills from **mtime
   only** — it never parses the filename. So even after fixing the filename parser, a
   direct `media-import` on a Telegram export would still apply the export date.
2. There is no read-only way to inspect a file and see which date the chain *would* pick
   before mutating anything, which makes troubleshooting these cases tedious.

## Goals

- Recover the Telegram post date from photo filenames during both normalize and import.
- Leave video (and any EXIF-bearing) behavior unchanged.
- Provide a read-only `media-info <file>` tool to troubleshoot date resolution before
  normalizing.
- Keep a single source of truth for date-resolution precedence (no logic duplicated
  across tools).

## Non-goals

- Broad/loose day-first date matching anywhere in a filename (rejected to avoid
  misreading ambiguous names like `03-04-2026`). Matching is Telegram-specific.
- Changing the canonical output filename format (`YYYYMMDD_HHMMSS`).
- Any change to how EXIF-bearing files (e.g. videos) are dated.

## Design

### 1. Recognize the Telegram filename date

In `media-common.sh`, extend `parse_date_from_filename` with a third pattern, tried
**after** the existing `re_prefixed` and `re_dashed` patterns so it never shadows
ISO-style names:

```
re_telegram='[@_]([0-9]{2})-([0-9]{2})-([0-9]{4})_([0-9]{2})-([0-9]{2})-([0-9]{2})'
#            sep   DD          MM          YYYY        HH          MM          SS
```

- Anchored on the `@` or `_` separator that precedes the date in Telegram exports,
  keeping the match tight (Telegram-specific scope).
- Reorders day-first capture groups into exiftool's `YYYY:MM:DD HH:MM:SS`:
  `photo_455@21-06-2026_15-17-04` → `2026:06:21 15:17:04`.

Precedence is unchanged overall: **EXIF CreateDate → filename → mtime**.

### 2. Share one fill-chain across both tools

Currently `media-normalize`'s `fill_missing_dates` (EXIF→filename→mtime) and
`media-import`'s `fill_missing_dates_for_import` (mtime-only) are separate
implementations.

- Move a single `fill_missing_dates <dir>` function into `media-common.sh`, implementing
  the EXIF→filename→mtime chain and honoring the existing `DRY_RUN` and `RECURSIVE`
  globals.
- `media-normalize` calls the shared function (behavior identical to today).
- `media-import` replaces `fill_missing_dates_for_import` with a call to the shared
  function before its copy/move step, so a direct `media-import` on a Telegram export now
  recovers post dates too.
- `default.nix` already ships `media-common.sh`; no packaging change for this part.

### 3. New `media-info <file>` troubleshooting tool

A new read-only script `media-info.sh`, wrapped as `media-info` in `default.nix`
alongside `media-normalize` and `media-import`. It mutates nothing; it explains what the
chain *would* do.

For the given file it prints:

1. **Embedded date tags** — `DateTimeOriginal`, `CreateDate`, `ModifyDate` (EXIF/QuickTime)
   via exiftool.
2. **Filesystem date** — `FileModifyDate` (mtime), the last-resort fallback.
3. **Filename parse** — what `parse_date_from_filename` extracts, or `(no match)`,
   reusing the shared function so it cannot drift from real logic.
4. **Resolved date + source** — the single date the normalize/import chain would pick,
   labeled `EXIF` / `filename` / `mtime`.
5. **Resulting name** — the canonical `YYYYMMDD_HHMMSS.ext` the file would be renamed to.

To support clean reuse, factor the "resolve date + source" decision into a shared
`resolve_date <file>` helper in `media-common.sh`, which both `media-info` (display) and
the fill-chain (section 2) build on — one source of truth for precedence.

Expected output for the two samples:

```
$ media-info photo_455@21-06-2026_15-17-04.jpg
  EXIF CreateDate : (none)
  FileModifyDate  : 2026:06:29 14:12:17   (export date)
  Filename parse  : 2026:06:21 15:17:04   (telegram)
  -> Resolved     : 2026:06:21 15:17:04   [source: filename]
  -> Would become : 20260621_151704.jpg

$ media-info IMG_3449.MOV
  EXIF CreateDate : 2026:06:18 18:50:10
  FileModifyDate  : 2026:06:29 14:12:16
  Filename parse  : (no match)
  -> Resolved     : 2026:06:18 18:50:10   [source: EXIF]
  -> Would become : 20260618_185010.mov
```

`media-info` takes one or more file arguments. Usage error (no args / missing file) exits
non-zero with a clear message. It does not require `MEDIA_HOME`.

## Components touched

| File | Change |
|------|--------|
| `media-common.sh` | Add `re_telegram` pattern to `parse_date_from_filename`; add shared `fill_missing_dates <dir>` and `resolve_date <file>` helpers |
| `media-normalize.sh` | Use shared `fill_missing_dates` (drop local copy) |
| `media-import.sh` | Replace `fill_missing_dates_for_import` with shared `fill_missing_dates` |
| `media-info.sh` | New read-only inspector script |
| `default.nix` | Add `media-info` to the wrapped-scripts loop |

## Error handling

- `media-info` with no arguments or a non-existent file: print error to stderr, exit 1.
- Existing `DRY_RUN`/`RECURSIVE` semantics preserved for normalize and import.
- Date parsing failures fall through the existing chain to mtime (unchanged safety net).

## Testing / verification

Against copies of the two sample files in a scratch dir:

1. `media-info` on the photo reports `Resolved … [source: filename]` =
   `2026:06:21 15:17:04` and `Would become 20260621_151704.jpg`.
2. `media-info` on the video reports `Resolved … [source: EXIF]` =
   `2026:06:18 18:50:10` and `Would become 20260618_185010.mov`.
3. `media-normalize --dry-run` on the photo shows it setting the date from the filename
   (post date), not mtime.
4. `media-import --dry-run` on the photo maps it under `.../2026/06/20260621_151704.jpg`
   (post date), confirming import now uses the filename fallback.
5. `parse_date_from_filename` still returns the same results for existing
   `IMG_YYYYMMDD_HHMMSS` and ISO `YYYY-MM-DD` names (no regression).
6. `just lint` / shellcheck clean; `nix build` of the package succeeds.
