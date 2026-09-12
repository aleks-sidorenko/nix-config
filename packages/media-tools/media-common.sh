#!/usr/bin/env bash
set -euo pipefail

EXTENSIONS="jpg jpeg png heic mp4 mov"
# %%le lowercases the extension so imported files match the normalized form
# (e.g. .MOV -> .mov), consistent with media-normalize and media-info.
FILENAME_FORMAT="%Y%m%d_%H%M%S%%-c.%%le"
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
          elif set_all_dates "$file" "$date"; then
            print_info "Set date from filename: $file -> $date"
          else
            print_error "Skipping (metadata write failed): $file"
          fi ;;
        mtime)
          if [[ "$DRY_RUN" == true ]]; then
            print_info "[dry-run] Set date from mtime: $file"
          elif set_all_dates "$file" --from-mtime; then
            print_info "Set date from mtime: $file"
          else
            print_error "Skipping (metadata write failed): $file"
          fi ;;
        *)
          print_error "fill_missing_dates: unknown source '$source' for $file" ;;
      esac
    done < <(find "$dir" "${find_depth[@]}" -iname "*.$ext" -type f -print0 2>/dev/null)
  done
}

# Build the canonical normalized basename (YYYYMMDD_HHMMSS + lowercased
# extension) from an exiftool-style date and a file (used for its extension).
# Echoes empty string if <date> is not a valid "YYYY:MM:DD HH:MM:SS".
canonical_name_from_date() {
  local date="$1" file="$2"
  [[ "$date" =~ ^[0-9]{4}:[0-9]{2}:[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}$ ]] || return 0
  local compact="${date//[: ]/}"  # YYYY:MM:DD HH:MM:SS -> YYYYMMDDHHMMSS
  local ext="${file##*.}"
  [[ "$ext" == "$file" ]] && ext="" || ext=".${ext,,}"
  printf '%s_%s%s\n' "${compact:0:8}" "${compact:8:6}" "$ext"
}

# Echo the canonical basename a file would be renamed to under normal (no
# --date) normalization: resolve its date (EXIF -> filename -> mtime) and format
# it. Empty when no date can be resolved.
canonical_basename() {
  local file="$1" date
  IFS=$'\t' read -r date _ < <(resolve_date "$file")
  canonical_name_from_date "$date" "$file"
}

# Echo a file's modification time as a Unix epoch (GNU stat, then BSD stat).
mtime_epoch() {
  stat -c "%Y" "$1" 2>/dev/null || stat -f "%m" "$1" 2>/dev/null
}

# Rename SRC to DST, tolerating case-only renames (e.g. .MP4 -> .mp4) on
# case-insensitive filesystems (macOS APFS/HFS+). There a plain `mv a.MP4 a.mp4`
# fails with "are the same file" because both names share one inode; go through a
# temporary name so the on-disk case still changes.
case_safe_mv() {
  local src="$1" dst="$2"
  [[ "$src" == "$dst" ]] && return 0
  if [[ -e "$dst" && "$src" -ef "$dst" ]]; then
    local tmp="${src}.casemv.$$"
    mv -- "$src" "$tmp"
    mv -- "$tmp" "$dst"
  else
    mv -- "$src" "$dst"
  fi
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

# Resolve media-import SRC and DEST from positional args (cp/mv-style: the
# trailing arg is the destination). $MEDIA_HOME is the default library root.
# Echoes TAB-separated "<SRC>\t<DEST_ROOT>"; DEST_ROOT may be empty when neither
# a DEST arg nor $MEDIA_HOME is set (the caller is responsible for erroring).
#   0 args -> SRC=.   DEST=$MEDIA_HOME
#   1 arg  -> SRC=$1  DEST=$MEDIA_HOME
#   2 args -> SRC=$1  DEST=$2
resolve_src_dest() {
  local src dest
  if [[ $# -ge 2 ]]; then
    src="$1"
    dest="$2"
  else
    src="${1:-.}"
    dest="${MEDIA_HOME:-}"
  fi
  printf '%s\t%s\n' "$src" "$dest"
}

# Exiftool maxdepth flag based on RECURSIVE
exiftool_depth_args() {
  if [[ "$RECURSIVE" == false ]]; then
    echo "-maxdepth 0"
  fi
}
