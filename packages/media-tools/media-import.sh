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

# Ensure all matching files have a CreateDate (fill from mtime if missing).
# This is done in a temporary copy of metadata only — source files are NOT modified.
# Exiftool's -o with date format skips files without CreateDate, so we need this.
fill_missing_dates_for_import() {
  local find_depth=("-maxdepth" "1")
  if [[ "$RECURSIVE" == true ]]; then
    find_depth=()
  fi

  for ext in $EXTENSIONS; do
    while IFS= read -r -d '' file; do
      local create_date
      create_date=$(exiftool -s3 -CreateDate "$file" 2>/dev/null || true)

      if [[ -z "$create_date" || "$create_date" == "0000:00:00 00:00:00" ]]; then
        if [[ "$DRY_RUN" == false ]]; then
          exiftool -overwrite_original '-CreateDate<FileModifyDate' "$file" 2>/dev/null || true
        fi
      fi
    done < <(find "$SRC" "${find_depth[@]}" -iname "*.$ext" -type f -print0 2>/dev/null)
  done
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
date_format="$DST/%Y/%m/$FILENAME_FORMAT"

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
    -p "\$filename -> $DST/\$CreateDate" \
    -d "%Y/%m/%Y%m%d_%H%M%S.%le" \
    "$SRC" 2>/dev/null || true
elif [[ "$MOVE" == true ]]; then
  # Fill missing CreateDate from mtime so exiftool -o can resolve all files
  fill_missing_dates_for_import

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
      -o . \
      "-FileName<CreateDate" \
      -d "$date_format" \
      -progress \
      "$SRC"

    # Delete source files after successful copy
    for file in "${src_files[@]}"; do
      rm -- "$file"
      print_info "Removed source: $file"
    done
  fi
else
  # Fill missing CreateDate from mtime so exiftool -o can resolve all files
  fill_missing_dates_for_import

  # Copy mode
  run_exiftool_import -o . "-FileName<CreateDate" -d "$date_format" -progress
fi

print_info "Done."
