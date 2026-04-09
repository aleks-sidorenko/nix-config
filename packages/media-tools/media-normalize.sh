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
