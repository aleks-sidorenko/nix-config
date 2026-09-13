#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=media-common.sh
source "$SCRIPT_DIR/media-common.sh"

MOVE=false

usage() {
  cat <<EOF
Usage: media-import [OPTIONS] [SOURCE] [DEST]

Import media files into <DEST>/All/YYYY/MM/, organized by capture date.
DEST is the media library root and, like cp/mv, is the trailing argument;
it defaults to \$MEDIA_HOME when omitted.

Options:
  --dry-run     Preview changes without modifying files
  --move        Move files instead of copy (default: copy)
  --recursive   Process subdirectories
  -h, --help    Show this help

SOURCE defaults to the current directory.
DEST defaults to \$MEDIA_HOME (e.g., ~/Media).

Examples:
  media-import ./dump                                # -> \$MEDIA_HOME/All/YYYY/MM
  media-import ./dump /mnt/usb/home/alexander/Media  # back up to a USB disk
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

if [[ ${#POSITIONAL[@]} -gt 2 ]]; then
  print_error "Too many arguments; expected at most [SOURCE] [DEST]."
  usage
  exit 1
fi

IFS=$'\t' read -r SRC DEST_ROOT < <(resolve_src_dest "${POSITIONAL[@]}")

if [[ -z "$DEST_ROOT" ]]; then
  print_error "No destination given and MEDIA_HOME is not set."
  print_error "Pass a DEST or set MEDIA_HOME to your library root (e.g., ~/Media)."
  exit 1
fi

if [[ ! -d "$SRC" ]]; then
  print_error "Source directory does not exist: $SRC"
  exit 1
fi

DST="$DEST_ROOT/All"

print_info "Importing media from: $SRC"
print_info "Destination: $DST"
[[ "$DRY_RUN" == true ]] && print_info "DRY RUN - no files will be modified"
[[ "$MOVE" == true ]] && print_info "Mode: move" || print_info "Mode: copy"

depth_args=$(exiftool_depth_args)

# Select media files to import: by extension, above the size threshold, honoring
# --recursive. exiftool has no -print0; -p prints one path per line.
# shellcheck disable=SC2086
mapfile -t import_files < <(
  exiftool $depth_args $(exiftool_ext_args) \
    -if "\$filesize# > $MIN_FILE_SIZE" \
    -p "\$Directory/\$FileName" \
    "$SRC" 2>/dev/null || true
)

if [[ ${#import_files[@]} -eq 0 ]]; then
  print_info "No files to import."
  print_info "Done."
  exit 0
fi

# Import one file at a time so progress is logged live (a bulk exiftool copy
# block-buffers its output, which looks stuck on large/slow imports). Each file
# is independent: a failure is logged and the run continues.
for file in "${import_files[@]}"; do
  IFS=$'\t' read -r rdate rsource < <(resolve_date "$file")
  newname=$(canonical_name_from_date "$rdate" "$file")
  if [[ -z "$newname" ]]; then
    print_error "Skipping (could not determine date): $file"
    continue
  fi
  compact="${rdate//[: ]/}"  # YYYY:MM:DD HH:MM:SS -> YYYYMMDDHHMMSS
  dest_dir="$DST/${compact:0:4}/${compact:4:2}"

  if [[ "$DRY_RUN" == true ]]; then
    print_info "[dry-run] Imported: $file -> $dest_dir/$newname  [$rsource]"
    continue
  fi

  # Stamp the resolved date into the source's EXIF (unless it already came from
  # EXIF) so the imported copy carries a durable CreateDate.
  case "$rsource" in
    filename) set_all_dates "$file" "$rdate" >/dev/null 2>&1 || true ;;
    mtime)    set_all_dates "$file" --from-mtime >/dev/null 2>&1 || true ;;
  esac

  mkdir -p "$dest_dir"
  target=$(unique_target "$dest_dir" "$newname" "$file")
  if cp -p -- "$file" "$target"; then
    print_info "Imported: $file -> $target"
    if [[ "$MOVE" == true ]]; then
      rm -- "$file" && print_info "Removed source: $file"
    fi
  else
    print_error "Skipping (copy failed): $file"
  fi
done

print_info "Done."
