# Media Tools CLI

## Goal

Provide two CLI tools (`media-normalize`, `media-import`) for managing personal media files — normalizing filenames/metadata and organizing into a canonical folder structure.

## Background

Ported from [old dotfiles](https://github.com/aleks-sidorenko/dotfiles/blob/master/shell/plugins/img/img.plugin.zsh) with improved naming, separation of concerns, and consistent argument handling. Phone mount/import is out of scope — will be a separate module.

## Conventions

- **All dates are local time.** No timezone conversion is performed. EXIF `CreateDate` is local time by convention; filename-parsed and mtime dates are also local.
- **Idempotency.** Both tools are safe to run multiple times. Files already matching the target name pattern (`YYYYMMDD_HHMMSS[%-c].ext`) with a valid EXIF `CreateDate` are skipped by `media-normalize`. Files already present at the destination are handled by exiftool's `%-c` auto-increment in `media-import`.

## Tools

### `media-normalize`

Fix metadata and filenames in-place within a directory.

**Steps (in order):**
1. Lowercase file extensions via shell `mv` (`.JPG` → `.jpg`, `.MOV` → `.mov`)
2. Set EXIF `CreateDate`:
   - If `--date` provided: force-write the given date to ALL files (overrides any existing `CreateDate`)
   - Otherwise: fill missing `CreateDate` using fallback chain (see below) — writes to the file-type-appropriate tag
3. Skip renaming for files whose filename already matches `YYYYMMDD_HHMMSS*.ext` and have a valid `CreateDate` (EXIF backfill in step 2 still applies). When `--date` is used, all files are renamed (no skip).
4. Rename remaining files to `YYYYMMDD_HHMMSS%-c.ext` based on resolved `CreateDate`

**Date fallback chain:**
1. Existing EXIF `CreateDate` — use as-is (skip if `0000:00:00 00:00:00`)
2. Parse date from filename — supported patterns:
   - `YYYYMMDD_HHMMSS` (target format)
   - `IMG_YYYYMMDD_HHMMSS` (Android/iOS camera)
   - `PXL_YYYYMMDD_HHMMSS` (Pixel camera)
   - `VID_YYYYMMDD_HHMMSS` (Android video)
   - `Screenshot_YYYYMMDD_HHMMSS` (screenshots)
   - `YYYY-MM-DD_HH-MM-SS` (alternative separator)
   - `YYYY-MM-DD HH.MM.SS` (macOS screenshots)
3. File modification date — last resort

When a date is resolved from fallback (steps 2-3), it is written back to EXIF `CreateDate` before renaming.

**Usage:**
```
media-normalize [OPTIONS] [DIRECTORY]
```

| Flag | Description |
|---|---|
| `--dry-run` | Preview changes without modifying files |
| `--recursive` | Process subdirectories |
| `--date "YYYY-MM-DD HH:MM:SS"` | Force-set `CreateDate` on all files, bypassing the fallback chain. The oldest file (by mtime) gets this exact date; other files are offset relative to the oldest, preserving their time differences. Useful for digitized photos, video frame exports, or any files with wrong/missing dates. |
| (no flag) | Process only top-level files in directory |

- `DIRECTORY` defaults to `.`

**Notes:**
- PNG files rarely have EXIF `CreateDate` — they will typically hit the filename-parse or mtime fallback.
- Video files (`.mp4`, `.mov`) use QuickTime metadata tags internally; exiftool maps `-CreateDate` to the correct tag per format.

### `media-import`

Organize media files into the canonical folder structure. Does not modify source files in-place — only reads metadata to determine destination path.

**What it does:**
- Reads `CreateDate` from source files to determine `YYYY/MM` destination
- Copies (or moves) files into `$MEDIA_HOME/All/YYYY/MM/YYYYMMDD_HHMMSS%-c.ext`
- Skips files smaller than 30KB (filters thumbnails and messaging app artifacts)
- Uses exiftool's `-o` which is aware of existing files at the destination — `%-c` increments correctly across runs
- If source files have no `CreateDate` (e.g., PNG without EXIF), falls back to file modification date for destination path — run `media-normalize` first for best results

**Usage:**
```
media-import [OPTIONS] [SOURCE]
```

| Flag | Description |
|---|---|
| `--dry-run` | Preview changes without modifying files |
| `--move` | Move files instead of copy (default: copy) |
| `--recursive` | Process subdirectories |
| (no flag) | Process only top-level files in source |

- `SOURCE` defaults to `.`
- Requires `MEDIA_HOME` environment variable — errors with a clear message if unset

### Supported Extensions

`jpg`, `jpeg`, `png`, `heic`, `mp4`, `mov`

### Filename Format

`YYYYMMDD_HHMMSS%-c.ext` where `%-c` is exiftool's auto-increment copy number for same-second duplicates. The first file has no suffix; duplicates get `-1`, `-2`, etc. Extensions are always lowercase.

## Error Handling

- Unsupported file extensions: silently skipped
- Missing `MEDIA_HOME` (on `media-import`): error with message
- Non-existent source directory: error
- `--dry-run`: prints what would happen, no modifications

## Nix Architecture

### Package: `packages/media-tools/`

Nix derivation producing `media-normalize` and `media-import` scripts with wrapped runtime dependencies:
- `exiftool`
- `coreutils`

### Home-manager module: `modules/home/media/tools/`

```nix
options.${namespace}.media.tools = {
  enable = mkBoolOpt false "Media management CLI tools";
  mediaHome = mkOpt types.str
    "${config.home.homeDirectory}/Pictures/Photo"
    "Root directory for media library";
};

config = mkIf cfg.enable {
  home.packages = [ pkgs.nix-config.media-tools ];
  home.sessionVariables.MEDIA_HOME = cfg.mediaHome;
};
```

### Role integration

`modules/home/roles/media/` updated to include `nix-config.media.tools = enabled;`.
