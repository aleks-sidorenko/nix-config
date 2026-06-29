#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=media-common.sh
source "$SCRIPT_DIR/media-common.sh"

usage() {
  cat <<EOF
Usage: media-info FILE [FILE...]

Show how each file's date would be resolved (EXIF -> filename -> mtime) before
normalizing or importing. Read-only: modifies nothing.
EOF
}

if [[ $# -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  [[ $# -eq 0 ]] && exit 1 || exit 0
fi

inspect() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    print_error "Not a file: $file"
    return 1
  fi

  local create_date modify_date fs_date parsed pname date source ext base
  create_date=$(exiftool -s3 -CreateDate "$file" 2>/dev/null || true)
  modify_date=$(exiftool -s3 -ModifyDate "$file" 2>/dev/null || true)
  fs_date=$(exiftool -s3 -d "%Y:%m:%d %H:%M:%S" -FileModifyDate "$file" 2>/dev/null || true)
  parsed=$(parse_date_from_filename "$file")
  pname=$(filename_pattern_name "$file")

  IFS=$'\t' read -r date source < <(resolve_date "$file")

  ext="${file##*.}"
  ext="${ext,,}"
  # canonical name from resolved date (YYYY:MM:DD HH:MM:SS -> YYYYMMDD_HHMMSS)
  base="${date//[: ]/}"
  base="${base:0:8}_${base:8:6}"

  echo "$file"
  printf '  EXIF CreateDate : %s\n' "${create_date:-(none)}"
  printf '  EXIF ModifyDate : %s\n' "${modify_date:-(none)}"
  printf '  FileModifyDate  : %s\n' "${fs_date:-(none)}"
  if [[ -n "$parsed" ]]; then
    printf '  Filename parse  : %s   (%s)\n' "$parsed" "$pname"
  else
    printf '  Filename parse  : (no match)\n'
  fi
  printf '  -> Resolved     : %s   [source: %s]\n' "$date" "$source"
  printf '  -> Would become : %s.%s\n' "$base" "$ext"
  echo ""
}

rc=0
for f in "$@"; do
  inspect "$f" || rc=1
done
exit "$rc"
