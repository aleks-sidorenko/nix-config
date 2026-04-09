# Media Tools Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Two CLI tools (`media-normalize`, `media-import`) packaged as a Nix derivation with a home-manager module for managing personal media files.

**Architecture:** Shell scripts wrapped via `pkgs.writeShellScriptBin` inside a Nix package at `packages/media-tools/`. A thin home-manager module at `modules/home/media/tools/` enables the package and sets `MEDIA_HOME`. The media role aggregates this module.

**Tech Stack:** Bash, exiftool, Nix (snowfall-lib), home-manager

**Spec:** `docs/specs/2026-04-09-media-tools-design.md`

---

## File Structure

| File | Responsibility |
|---|---|
| `packages/media-tools/default.nix` | Nix derivation: builds `media-normalize` and `media-import` scripts with wrapped deps |
| `packages/media-tools/media-normalize.sh` | Shell script: normalize media filenames and EXIF metadata |
| `packages/media-tools/media-import.sh` | Shell script: import media into `$MEDIA_HOME/All/YYYY/MM/` |
| `packages/media-tools/media-common.sh` | Shared constants and helpers (extensions, filename patterns, argument parsing) |
| `modules/home/media/tools/default.nix` | Home-manager module: enable toggle + `MEDIA_HOME` config |
| `modules/home/roles/media/default.nix` | Modify: add `tools = enabled;` to media role |

---

### Task 1: Shared helpers (`media-common.sh`)

**Files:**
- Create: `packages/media-tools/media-common.sh`

- [ ] **Step 1: Create shared constants and helper functions**

```bash
#!/usr/bin/env bash
set -euo pipefail

EXTENSIONS="jpg jpeg png heic mp4 mov"
FILENAME_FORMAT="%Y%m%d_%H%M%S%%-c.%%e"
MIN_FILE_SIZE=30000  # 30KB - skip thumbnails/artifacts

# Normalized filename pattern: YYYYMMDD_HHMMSS with optional -N suffix
NORMALIZED_PATTERN='^[0-9]{8}_[0-9]{6}(-[0-9]+)?\.'

# Filename date patterns for fallback parsing
# Returns date string in "YYYY:MM:DD HH:MM:SS" exiftool format, or empty
parse_date_from_filename() {
  local filename
  filename=$(basename "$1")
  filename="${filename%.*}"  # strip extension

  local date_str=""

  # Try each pattern
  if [[ "$filename" =~ ^(IMG_|PXL_|VID_|Screenshot_)?([0-9]{4})([0-9]{2})([0-9]{2})_([0-9]{2})([0-9]{2})([0-9]{2}) ]]; then
    date_str="${BASH_REMATCH[2]}:${BASH_REMATCH[3]}:${BASH_REMATCH[4]} ${BASH_REMATCH[5]}:${BASH_REMATCH[6]}:${BASH_REMATCH[7]}"
  elif [[ "$filename" =~ ([0-9]{4})-([0-9]{2})-([0-9]{2})[_ ]([0-9]{2})[-.]([0-9]{2})[-.]([0-9]{2}) ]]; then
    date_str="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}:${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"
  fi

  echo "$date_str"
}

# Build exiftool extension args: -ext jpg -ext jpeg -ext png ...
exiftool_ext_args() {
  local args=""
  for ext in $EXTENSIONS; do
    args="$args -ext $ext"
  done
  echo "$args"
}

# Print error to stderr
print_error() {
  echo "ERROR: $1" >&2
}

# Print info message
print_info() {
  echo ":: $1"
}

# Parse common flags. Sets DRY_RUN, RECURSIVE, and remaining args in POSITIONAL.
# Tool-specific flags (e.g. --move) should be parsed before calling this.
DRY_RUN=false
RECURSIVE=false
POSITIONAL=()

parse_common_args() {
  DRY_RUN=false
  RECURSIVE=false
  POSITIONAL=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)  DRY_RUN=true; shift ;;
      --recursive) RECURSIVE=true; shift ;;
      --help|-h)  usage; exit 0 ;;
      -*)         print_error "Unknown option: $1"; usage; exit 1 ;;
      *)          POSITIONAL+=("$1"); shift ;;
    esac
  done
}

# Exiftool maxdepth flag based on RECURSIVE
exiftool_depth_args() {
  if [[ "$RECURSIVE" == false ]]; then
    echo "-maxdepth 0"
  fi
}
```

- [ ] **Step 2: Commit**

```bash
git add packages/media-tools/media-common.sh
git commit -m "feat(media-tools): add shared helpers and constants"
```

---

### Task 2: `media-normalize` script

**Files:**
- Create: `packages/media-tools/media-normalize.sh`

- [ ] **Step 1: Create the media-normalize script**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=media-common.sh
source "$SCRIPT_DIR/media-common.sh"

usage() {
  cat <<EOF
Usage: media-normalize [OPTIONS] [DIRECTORY]

Normalize media filenames and EXIF metadata in-place.

Steps:
  1. Lowercase file extensions
  2. Fill missing EXIF CreateDate (from filename or mtime)
  3. Rename files to YYYYMMDD_HHMMSS format

Options:
  --dry-run     Preview changes without modifying files
  --recursive   Process subdirectories
  -h, --help    Show this help

DIRECTORY defaults to current directory.
EOF
}

# Step 1: Lowercase extensions
lowercase_extensions() {
  local dir="$1"
  local find_depth=("-maxdepth" "1")
  if [[ "$RECURSIVE" == true ]]; then
    find_depth=()
  fi

  for ext in $EXTENSIONS; do
    local EXT
    EXT=$(echo "$ext" | tr '[:lower:]' '[:upper:]')
    # Find files with uppercase extension
    while IFS= read -r -d '' file; do
      local newfile="${file%."$EXT"}.$ext"
      if [[ "$DRY_RUN" == true ]]; then
        print_info "[dry-run] Rename: $file -> $newfile"
      else
        mv -- "$file" "$newfile"
        print_info "Renamed: $file -> $newfile"
      fi
    done < <(find "$dir" "${find_depth[@]}" -name "*.$EXT" -type f -print0 2>/dev/null)
  done
}

# Step 2: Fill missing EXIF CreateDate
fill_missing_dates() {
  local dir="$1"
  local find_depth=("-maxdepth" "1")
  if [[ "$RECURSIVE" == true ]]; then
    find_depth=()
  fi

  for ext in $EXTENSIONS; do
    while IFS= read -r -d '' file; do
      # Check if CreateDate exists and is valid
      local create_date
      create_date=$(exiftool -s3 -CreateDate "$file" 2>/dev/null || true)

      if [[ -n "$create_date" && "$create_date" != "0000:00:00 00:00:00" ]]; then
        continue  # already has valid date
      fi

      # Fallback 1: parse from filename
      local parsed_date
      parsed_date=$(parse_date_from_filename "$file")

      if [[ -n "$parsed_date" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
          print_info "[dry-run] Set CreateDate from filename: $file -> $parsed_date"
        else
          exiftool -overwrite_original -CreateDate="$parsed_date" "$file"
          print_info "Set CreateDate from filename: $file -> $parsed_date"
        fi
        continue
      fi

      # Fallback 2: file modification date
      if [[ "$DRY_RUN" == true ]]; then
        print_info "[dry-run] Set CreateDate from mtime: $file"
      else
        exiftool -overwrite_original '-CreateDate<FileModifyDate' "$file"
        print_info "Set CreateDate from mtime: $file"
      fi
    done < <(find "$dir" "${find_depth[@]}" -iname "*.$ext" -type f -print0 2>/dev/null)
  done
}

# Step 3: Rename files to canonical format
rename_files() {
  local dir="$1"
  local depth_args
  depth_args=$(exiftool_depth_args)

  # Skip files already matching the normalized pattern
  # exiftool -if condition skips files whose basename matches YYYYMMDD_HHMMSS
  local dry_run_flag=""
  if [[ "$DRY_RUN" == true ]]; then
    dry_run_flag="-testname"
  else
    dry_run_flag="-filename"
  fi

  # shellcheck disable=SC2086
  exiftool \
    $depth_args \
    $(exiftool_ext_args) \
    -if 'not ($filename =~ /^[0-9]{8}_[0-9]{6}/)' \
    "${dry_run_flag}<CreateDate" \
    -d "$FILENAME_FORMAT" \
    -overwrite_original \
    "$dir" 2>/dev/null || true
}

# Main
parse_common_args "$@"
DIR="${POSITIONAL[0]:-.}"

if [[ ! -d "$DIR" ]]; then
  print_error "Directory does not exist: $DIR"
  exit 1
fi

print_info "Normalizing media in: $DIR"
[[ "$DRY_RUN" == true ]] && print_info "DRY RUN - no files will be modified"

lowercase_extensions "$DIR"
fill_missing_dates "$DIR"
rename_files "$DIR"

print_info "Done."
```

- [ ] **Step 2: Commit**

```bash
git add packages/media-tools/media-normalize.sh
git commit -m "feat(media-tools): add media-normalize script"
```

---

### Task 3: `media-import` script

**Files:**
- Create: `packages/media-tools/media-import.sh`

- [ ] **Step 1: Create the media-import script**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=media-common.sh
source "$SCRIPT_DIR/media-common.sh"

MOVE=false

usage() {
  cat <<EOF
Usage: media-import [OPTIONS] [SOURCE]

Import media files into \$MEDIA_HOME/All/YYYY/MM/ structure.

Options:
  --dry-run     Preview changes without modifying files
  --move        Move files instead of copy (default: copy)
  --recursive   Process subdirectories
  -h, --help    Show this help

SOURCE defaults to current directory.
Requires MEDIA_HOME environment variable.
EOF
}

# Override parse_common_args to handle --move
parse_args() {
  local remaining=()
  MOVE=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --move) MOVE=true; shift ;;
      *)      remaining+=("$1"); shift ;;
    esac
  done

  parse_common_args "${remaining[@]}"
}

# Main
parse_args "$@"
SRC="${POSITIONAL[0]:-.}"

if [[ -z "${MEDIA_HOME:-}" ]]; then
  print_error "MEDIA_HOME environment variable is not set."
  print_error "Set it to your media library root (e.g., ~/Pictures/Photo)"
  exit 1
fi

if [[ ! -d "$SRC" ]]; then
  print_error "Source directory does not exist: $SRC"
  exit 1
fi

DST="$MEDIA_HOME/All"
mkdir -p "$DST"

print_info "Importing media from: $SRC"
print_info "Destination: $DST"
[[ "$DRY_RUN" == true ]] && print_info "DRY RUN - no files will be modified"
[[ "$MOVE" == true ]] && print_info "Mode: move" || print_info "Mode: copy"

depth_args=$(exiftool_depth_args)
dst_format="$DST/%Y/%m/$FILENAME_FORMAT"

# Common exiftool args for selecting media files above size threshold
# shellcheck disable=SC2086
run_exiftool_import() {
  exiftool \
    $depth_args \
    $(exiftool_ext_args) \
    -if "\$filesize# > $MIN_FILE_SIZE" \
    "$@" \
    "$SRC" 2>/dev/null || true
}

if [[ "$DRY_RUN" == true ]]; then
  # Preview: use -p to print source -> destination mapping without copying
  # shellcheck disable=SC2086
  exiftool \
    $depth_args \
    $(exiftool_ext_args) \
    -if "\$filesize# > $MIN_FILE_SIZE" \
    -p "\$filename -> $DST/\$DateTimeOriginal" \
    -d "%Y/%m/%Y%m%d_%H%M%S.%le" \
    "$SRC" 2>/dev/null || true
elif [[ "$MOVE" == true ]]; then
  # Collect matching source file paths before copying
  mapfile -d '' src_files < <(
    # shellcheck disable=SC2086
    exiftool $depth_args $(exiftool_ext_args) \
      -if "\$filesize# > $MIN_FILE_SIZE" \
      -print0 "$SRC" 2>/dev/null || true
  )

  if [[ ${#src_files[@]} -eq 0 ]]; then
    print_info "No files to import."
  else
    # Copy to destination (no || true — fail loudly on copy errors)
    # shellcheck disable=SC2086
    exiftool \
      $depth_args \
      $(exiftool_ext_args) \
      -if "\$filesize# > $MIN_FILE_SIZE" \
      -o "$dst_format" \
      -d "$dst_format" \
      -progress \
      "$SRC"

    # Delete source files after successful copy
    for file in "${src_files[@]}"; do
      rm -- "$file"
      print_info "Removed source: $file"
    done
  fi
else
  # Copy mode
  run_exiftool_import -o "$dst_format" -d "$dst_format" -progress
fi

print_info "Done."
```

- [ ] **Step 2: Commit**

```bash
git add packages/media-tools/media-import.sh
git commit -m "feat(media-tools): add media-import script"
```

---

### Task 4: Nix package derivation

**Files:**
- Create: `packages/media-tools/default.nix`

- [ ] **Step 1: Create the Nix package**

```nix
{
  pkgs,
  lib,
  ...
}:
let
  runtimeDeps = with pkgs; [
    exiftool
    coreutils
    findutils
  ];
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "media-tools";
  version = "1.0.0";
  src = ./.;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin $out/lib/media-tools

    # Install shared lib
    cp media-common.sh $out/lib/media-tools/

    # Install scripts and wrap with runtime deps
    for script in media-normalize media-import; do
      cp "$script.sh" "$out/bin/$script"
      chmod +x "$out/bin/$script"

      # Patch source path to point to installed location
      substituteInPlace "$out/bin/$script" \
        --replace-fail 'SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"' \
        'SCRIPT_DIR="${placeholder "out"}/lib/media-tools"'

      wrapProgram "$out/bin/$script" \
        --prefix PATH : ${lib.makeBinPath runtimeDeps}
    done
  '';

  meta = with lib; {
    description = "CLI tools for managing personal media files";
    platforms = platforms.all;
  };
}
```

- [ ] **Step 2: Verify the package builds**

```bash
cd /Users/oleksandrsy/.nix-config
nix build .#media-tools
# Verify binaries exist
ls -la result/bin/
result/bin/media-normalize --help
result/bin/media-import --help
```

- [ ] **Step 3: Commit**

```bash
git add packages/media-tools/default.nix
git commit -m "feat(media-tools): add Nix package derivation"
```

---

### Task 5: Home-manager module

**Files:**
- Create: `modules/home/media/tools/default.nix`
- Modify: `modules/home/roles/media/default.nix`

- [ ] **Step 1: Create the home-manager module**

```nix
{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.media.tools;
in
{
  options.${namespace}.media.tools = {
    enable = mkBoolOpt false "Media management CLI tools (media-normalize, media-import)";
    mediaHome = mkOpt types.str "${config.home.homeDirectory}/Pictures/Photo" "Root directory for media library";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.${namespace}.media-tools ];
    home.sessionVariables.MEDIA_HOME = cfg.mediaHome;
  };
}
```

- [ ] **Step 2: Add tools to media role**

In `modules/home/roles/media/default.nix`, add `tools = enabled;` to the `${namespace}.media` block:

```nix
config = mkIf cfg.enable {
  ${namespace}.media = {
    players.vlc = enabled;
    shotwell = enabled;
    tools = enabled;
  };
};
```

- [ ] **Step 3: Verify flake check passes**

```bash
cd /Users/oleksandrsy/.nix-config
nix flake check
```

- [ ] **Step 4: Commit**

```bash
git add modules/home/media/tools/default.nix modules/home/roles/media/default.nix
git commit -m "feat(media-tools): add home-manager module and role integration"
```

---

### Task 6: Manual testing

- [ ] **Step 1: Build the package and test with sample files**

```bash
nix build .#media-tools

# Create test directory with sample files
mkdir -p /tmp/media-test
# Copy a few test images/videos there, or create dummy ones

# Test normalize
result/bin/media-normalize --dry-run /tmp/media-test

# Test import
MEDIA_HOME=/tmp/media-output result/bin/media-import --dry-run /tmp/media-test
```

- [ ] **Step 2: Test error cases**

```bash
# Missing MEDIA_HOME
unset MEDIA_HOME
result/bin/media-import /tmp/media-test  # should error

# Non-existent directory
result/bin/media-normalize /tmp/nonexistent  # should error

# Help flags
result/bin/media-normalize --help
result/bin/media-import --help
```

- [ ] **Step 3: Fix any issues found during testing**

- [ ] **Step 4: Final commit if fixes were needed**
