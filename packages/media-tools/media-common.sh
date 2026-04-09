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

  # Try each pattern (stored in variables to avoid bash 5.3 regex parsing issues with spaces in bracket expressions)
  local re_prefixed='^(IMG_|PXL_|VID_|Screenshot_)?([0-9]{4})([0-9]{2})([0-9]{2})_([0-9]{2})([0-9]{2})([0-9]{2})'
  local re_dashed='([0-9]{4})-([0-9]{2})-([0-9]{2})[_ ]([0-9]{2})[-.]([0-9]{2})[-.]([0-9]{2})'

  if [[ "$filename" =~ $re_prefixed ]]; then
    date_str="${BASH_REMATCH[2]}:${BASH_REMATCH[3]}:${BASH_REMATCH[4]} ${BASH_REMATCH[5]}:${BASH_REMATCH[6]}:${BASH_REMATCH[7]}"
  elif [[ "$filename" =~ $re_dashed ]]; then
    date_str="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}:${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"
  fi

  echo "$date_str"
}

# Set DateTimeOriginal, CreateDate, and ModifyDate on a file.
# Usage: set_all_dates <file> <date>        — set from literal date string
#        set_all_dates <file> --from-mtime   — copy from FileModifyDate
set_all_dates() {
  local file="$1"
  local date_or_flag="$2"

  if [[ "$date_or_flag" == "--from-mtime" ]]; then
    exiftool -overwrite_original \
      '-DateTimeOriginal<FileModifyDate' \
      '-CreateDate<FileModifyDate' \
      '-ModifyDate<FileModifyDate' \
      "$file"
  else
    exiftool -overwrite_original \
      -DateTimeOriginal="$date_or_flag" \
      -CreateDate="$date_or_flag" \
      -ModifyDate="$date_or_flag" \
      "$file"
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

# Exiftool maxdepth flag based on RECURSIVE
exiftool_depth_args() {
  if [[ "$RECURSIVE" == false ]]; then
    echo "-maxdepth 0"
  fi
}
