#!/usr/bin/env bash
set -euo pipefail

EXTENSIONS="jpg jpeg png heic mp4 mov"
FILENAME_FORMAT="%Y%m%d_%H%M%S%%-c.%%e"
MIN_FILE_SIZE=30000  # 30KB - skip thumbnails/artifacts

# Normalized filename pattern: YYYYMMDD_HHMMSS with optional -N suffix
NORMALIZED_PATTERN='^[0-9]{8}_[0-9]{6}(-[0-9]+)?\.'

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
      if [[ $# -ne 6 ]]; then
        print_error "filename pattern '$name' has ${#} group-order tokens (need 6); skipping"
        continue
      fi
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

# Decide which date a file would receive and where it comes from.
# Precedence: embedded EXIF/QuickTime CreateDate -> filename pattern -> file mtime.
# Echoes TAB-separated: "<YYYY:MM:DD HH:MM:SS>\t<EXIF|filename|mtime>".
resolve_date() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    print_error "resolve_date: not a file: $file"
    return 1
  fi

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

# Get timezone offset in +HH:MM format for a given epoch (or current time)
# Usage: get_tz_offset [epoch]
get_tz_offset() {
  local raw
  if [[ -n "${1:-}" ]]; then
    raw=$(date -d "@$1" "+%z" 2>/dev/null || \
          date -j -f "%s" "$1" "+%z" 2>/dev/null)
  else
    raw=$(date "+%z")
  fi
  # Convert +0300 to +03:00
  echo "${raw:0:3}:${raw:3:2}"
}

# Set DateTimeOriginal, CreateDate, ModifyDate and timezone offset tags.
# Usage: set_all_dates <file> <date> [tz_offset]  — set from literal date string
#        set_all_dates <file> --from-mtime         — copy from FileModifyDate
set_all_dates() {
  local file="$1"
  local date_or_flag="$2"

  if [[ "$date_or_flag" == "--from-mtime" ]]; then
    local tz_offset
    tz_offset=$(exiftool -s3 -d "%z" -FileModifyDate "$file" 2>/dev/null | sed 's/\(..\)$/:\1/')
    exiftool -overwrite_original \
      '-DateTimeOriginal<FileModifyDate' \
      '-CreateDate<FileModifyDate' \
      '-ModifyDate<FileModifyDate' \
      -OffsetTimeOriginal="$tz_offset" \
      -OffsetTimeDigitized="$tz_offset" \
      -OffsetTime="$tz_offset" \
      "$file"
  else
    local tz_offset="${3:-$(get_tz_offset)}"
    exiftool -overwrite_original \
      -DateTimeOriginal="$date_or_flag" \
      -CreateDate="$date_or_flag" \
      -ModifyDate="$date_or_flag" \
      -OffsetTimeOriginal="$tz_offset" \
      -OffsetTimeDigitized="$tz_offset" \
      -OffsetTime="$tz_offset" \
      "$file"
  fi
}

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
