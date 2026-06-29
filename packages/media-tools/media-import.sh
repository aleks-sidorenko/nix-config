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
  # Preview source -> destination without modifying anything. exiftool selects
  # the same files a real run would (extensions + size threshold + depth); dates
  # come from resolve_date (EXIF -> filename -> mtime) so Telegram filenames
  # preview correctly — exiftool's $CreateDate would be blank for them.
  mapfile -t preview_files < <(
    # shellcheck disable=SC2086
    exiftool -q -m $depth_args $(exiftool_ext_args) \
      -if "\$filesize# > $MIN_FILE_SIZE" \
      -p "\$Directory/\$FileName" \
      "$SRC" 2>/dev/null || true
  )

  if [[ ${#preview_files[@]} -eq 0 ]]; then
    print_info "No files to import."
  fi
  for file in "${preview_files[@]}"; do
    IFS=$'\t' read -r rdate rsource < <(resolve_date "$file")
    compact="${rdate//[: ]/}"  # YYYY:MM:DD HH:MM:SS -> YYYYMMDDHHMMSS
    ext="${file##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    print_info "$file -> $DST/${compact:0:4}/${compact:4:2}/${compact:0:8}_${compact:8:6}.$ext  [$rsource]"
  done
elif [[ "$MOVE" == true ]]; then
  # Fill missing CreateDate (filename pattern, else mtime) so exiftool -o can
  # resolve all files. NOTE: writes EXIF tags back to the SOURCE files.
  fill_missing_dates "$SRC"

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
  # Fill missing CreateDate (filename pattern, else mtime) so exiftool -o can
  # resolve all files. NOTE: writes EXIF tags back to the SOURCE files.
  fill_missing_dates "$SRC"

  # Copy mode
  run_exiftool_import -o . "-FileName<CreateDate" -d "$date_format" -progress
fi

print_info "Done."
