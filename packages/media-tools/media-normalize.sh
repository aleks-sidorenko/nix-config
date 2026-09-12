#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=media-common.sh
source "$SCRIPT_DIR/media-common.sh"

FORCE_DATE=""

usage() {
  cat <<EOF
Usage: media-normalize [OPTIONS] [DIRECTORY]

Normalize media filenames and EXIF metadata in-place.

Steps:
  1. Lowercase file extensions
  2. Fill missing EXIF CreateDate (from filename or mtime)
  3. Rename files to YYYYMMDD_HHMMSS format

Options:
  --dry-run                       Preview changes without modifying files
  --recursive                     Process subdirectories
  --date "YYYY-MM-DD HH:MM:SS"   Force-set CreateDate on ALL files.
                                  The oldest file (by mtime) gets this exact date.
                                  Other files are offset relative to the oldest,
                                  preserving their time differences.
  -h, --help                      Show this help

DIRECTORY defaults to current directory.
EOF
}

# Parse --date before common args
parse_args() {
  local remaining=()
  FORCE_DATE=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --date)
        if [[ $# -lt 2 ]]; then
          print_error "--date requires a value (e.g., --date \"2023-01-15 14:30:00\")"
          exit 1
        fi
        FORCE_DATE="$2"; shift 2 ;;
      *)
        remaining+=("$1"); shift ;;
    esac
  done

  parse_common_args "${remaining[@]}"
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
    while IFS= read -r -d '' file; do
      local newfile="${file%."$EXT"}.$ext"
      if [[ "$DRY_RUN" == true ]]; then
        print_info "[dry-run] Rename: $file -> $newfile"
      else
        case_safe_mv "$file" "$newfile"
        print_info "Renamed: $file -> $newfile"
      fi
    done < <(find "$dir" "${find_depth[@]}" -name "*.$EXT" -type f -print0 2>/dev/null)
  done
}

# Collect all matching media files
collect_media_files() {
  local dir="$1"
  local find_depth=("-maxdepth" "1")
  if [[ "$RECURSIVE" == true ]]; then
    find_depth=()
  fi

  for ext in $EXTENSIONS; do
    find "$dir" "${find_depth[@]}" -iname "*.$ext" -type f -print0 2>/dev/null
  done
}

# Step 2: Set EXIF CreateDate
set_dates() {
  local dir="$1"

  if [[ -n "$FORCE_DATE" ]]; then
    force_set_dates "$dir"
  else
    fill_missing_dates "$dir"
  fi
}

# Base epoch parsed from FORCE_DATE (accepts "-" or ":" date separators).
forced_base_epoch() {
  local formatted_date
  formatted_date=$(echo "$FORCE_DATE" | sed 's/-/:/g; s/\//:/g')
  date -d "${FORCE_DATE}" "+%s" 2>/dev/null || \
    date -j -f "%Y:%m:%d %H:%M:%S" "$formatted_date" "+%s" 2>/dev/null
}

# Oldest media file mtime (epoch) in <dir>, or empty when there are none.
oldest_media_mtime() {
  local dir="$1" oldest="" file mtime
  while IFS= read -r -d '' file; do
    mtime=$(mtime_epoch "$file")
    if [[ -z "$oldest" || "$mtime" -lt "$oldest" ]]; then
      oldest="$mtime"
    fi
  done < <(collect_media_files "$dir")
  echo "$oldest"
}

# Forced target date for <file>: base + (file_mtime - oldest_mtime), formatted
# as "YYYY:MM:DD HH:MM:SS". This is the --date offset rule used by both the real
# run and the dry-run preview.
forced_target_date() {
  local file="$1" base_epoch="$2" oldest_mtime="$3"
  local target_epoch=$(( base_epoch + ( $(mtime_epoch "$file") - oldest_mtime ) ))
  date -d "@${target_epoch}" "+%Y:%m:%d %H:%M:%S" 2>/dev/null || \
    date -j -f "%s" "$target_epoch" "+%Y:%m:%d %H:%M:%S" 2>/dev/null
}

# --date mode: force-set date with relative offsets from oldest file
force_set_dates() {
  local dir="$1"
  local base_epoch oldest_mtime
  base_epoch=$(forced_base_epoch)
  oldest_mtime=$(oldest_media_mtime "$dir")

  if [[ -z "$oldest_mtime" ]]; then
    print_info "No media files found."
    return
  fi

  # Set each file's date as base_date + (file_mtime - oldest_mtime)
  while IFS= read -r -d '' file; do
    local target_date offset
    target_date=$(forced_target_date "$file" "$base_epoch" "$oldest_mtime")
    offset=$(( $(mtime_epoch "$file") - oldest_mtime ))

    if [[ "$DRY_RUN" == true ]]; then
      print_info "[dry-run] Force CreateDate: $file -> $target_date (offset: ${offset}s)"
    else
      set_all_dates "$file" "$target_date" "$(get_tz_offset "$(( base_epoch + offset ))")"
      print_info "Force CreateDate: $file -> $target_date (offset: ${offset}s)"
    fi
  done < <(collect_media_files "$dir")
}

# Dry-run preview of step 3: print the rename each media file would receive,
# without touching anything. Normal mode skips already-normalized files and
# derives the name from resolve_date; --date mode renames all files using the
# same forced base + mtime-offset rule as force_set_dates. exiftool's own
# -testname is unusable here because in dry-run step 2 never writes CreateDate.
preview_rename() {
  local dir="$1"
  local base_epoch="" oldest_mtime=""
  if [[ -n "$FORCE_DATE" ]]; then
    base_epoch=$(forced_base_epoch)
    oldest_mtime=$(oldest_media_mtime "$dir")
  fi

  local file base newname
  while IFS= read -r -d '' file; do
    if [[ -n "$FORCE_DATE" ]]; then
      newname=$(canonical_name_from_date \
        "$(forced_target_date "$file" "$base_epoch" "$oldest_mtime")" "$file")
    else
      # Skip files already in canonical form (mirrors the real run's -if guard).
      base=$(basename "$file")
      if [[ "$base" =~ $NORMALIZED_PATTERN ]]; then
        continue
      fi
      newname=$(canonical_basename "$file")
    fi

    if [[ -n "$newname" ]]; then
      print_info "[dry-run] Rename: $file -> $(dirname "$file")/$newname"
    else
      print_info "[dry-run] Rename: $file -> (could not determine date)"
    fi
  done < <(collect_media_files "$dir")
}

# Step 3: Rename files to canonical format
rename_files() {
  local dir="$1"

  if [[ "$DRY_RUN" == true ]]; then
    preview_rename "$dir"
    return
  fi

  local depth_args
  depth_args=$(exiftool_depth_args)

  # When --date is used, rename all files (no skip)
  # Otherwise, skip files already matching the normalized pattern
  local if_args=()
  if [[ -z "$FORCE_DATE" ]]; then
    if_args=(-if 'not ($filename =~ /^[0-9]{8}_[0-9]{6}/)')
  fi

  # shellcheck disable=SC2086
  exiftool \
    $depth_args \
    $(exiftool_ext_args) \
    "${if_args[@]}" \
    "-filename<CreateDate" \
    -d "$FILENAME_FORMAT" \
    -overwrite_original \
    "$dir" 2>/dev/null || true
}

# Main
parse_args "$@"
DIR="${POSITIONAL[0]:-.}"

if [[ ! -d "$DIR" ]]; then
  print_error "Directory does not exist: $DIR"
  exit 1
fi

print_info "Normalizing media in: $DIR"
[[ "$DRY_RUN" == true ]] && print_info "DRY RUN - no files will be modified"
[[ -n "$FORCE_DATE" ]] && print_info "Force date: $FORCE_DATE (base for oldest file, others offset by mtime)"

lowercase_extensions "$DIR"
set_dates "$DIR"
rename_files "$DIR"

print_info "Done."
