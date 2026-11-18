usage() {
  cat <<EOF
Usage: disk-report

Show where disk space goes and what can be reclaimed, ranked by size, with the
command that reclaims each item. Read-only: deletes nothing, needs no sudo.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi
if [[ $# -gt 0 ]]; then
  usage >&2
  exit 1
fi

# Below this an item is noise next to the ones worth acting on.
MIN_KB=$((100 * 1024))

section() {
  if [[ -t 1 ]]; then
    printf '\n\033[1m%s\033[0m\n' "$1"
  else
    printf '\n%s\n' "$1"
  fi
}

row() {
  printf '  %7s  %-52s  %s\n' "$1" "$2" "${3:-}"
}

human() {
  numfmt --to=iec --from-unit=1024 "$1"
}

# Unreadable subtrees (TCC-protected app data) make du fail; size what it can.
kb_of() {
  { du -sk "$@" 2>/dev/null || true; } | awk '{ s += $1 } END { print s + 0 }'
}

# NAR sizes, so an estimate: optimised (hardlinked) paths take less on disk.
store_kb() {
  { xargs -r nix-store --query --size 2>/dev/null || true; } |
    awk '{ s += $1 } END { printf "%d\n", s / 1024 }'
}

# Paths are shown relative to ~ and shell-quoted so commands paste as-is.
pretty() {
  if [[ "$1" == "$HOME"/* ]]; then
    printf '%s/%q' "~" "${1#"$HOME"/}"
  else
    printf '%q' "$1"
  fi
}

# Emits "kb<TAB>label<TAB>command" so candidates can be ranked before printing.
candidate() {
  local kb="$1" label="$2" cmd="$3"
  ((kb >= MIN_KB)) && printf '%s\t%s\t%s\n' "$kb" "$label" "$cmd"
  return 0
}

candidate_path() {
  local path="$1" cmd="${2:-}"
  [[ -e "$path" ]] || return 0
  [[ -n "$cmd" ]] || cmd="rm -rf $(pretty "$path")"
  candidate "$(kb_of "$path")" "$(pretty "$path")" "$cmd"
}

# Each cache entry is listed on its own so the ranking points at the app.
candidate_children() {
  local root="$1" kb path
  [[ -d "$root" ]] || return 0
  while IFS=$'\t' read -r kb path; do
    candidate "$kb" "$(pretty "$path")" "rm -rf $(pretty "$path")"
  done < <(find "$root" -mindepth 1 -maxdepth 1 -exec du -sk {} + 2>/dev/null || true)
}

nix_store() {
  row "$(human "$(kb_of /nix/store)")" "/nix/store total"
  row "$(human "$(nix-store --gc --print-dead 2>/dev/null | store_kb)")" "garbage (unreachable)" "nix-collect-garbage"

  local profile generations
  for profile in /nix/var/nix/profiles/system "$HOME/.local/state/nix/profiles/home-manager" "$HOME/.local/state/nix/profiles/profile"; do
    [[ -e "$profile" ]] || continue
    generations=$(find "$(dirname "$profile")" -maxdepth 1 -name "$(basename "$profile")-*-link" | wc -l)
    ((generations > 3)) || continue
    row "$generations gens" "$(pretty "$profile")" "nh clean all --keep 3"
  done
}

dev_shells() {
  local link target owner now mtime kb
  local -A targets=() mtimes=()
  while read -r link; do
    target=$(readlink "$link") || continue
    [[ -e "$target" ]] || continue
    # Profiles and home-manager register auto roots too; only dev shells and
    # build outputs are safe to suggest deleting. nix-direnv pins every flake
    # input separately, so those are grouped by project.
    if [[ "$target" == */.direnv/* ]]; then
      owner="${target%%/.direnv/*}/.direnv"
    elif [[ "$(basename "$target")" == result* ]]; then
      owner="$target"
    else
      continue
    fi
    targets["$owner"]+="$(readlink -f "$target")"$'\n'
    mtimes["$owner"]=$(stat -c %Y "$owner")
  done < <(find /nix/var/nix/gcroots/auto -mindepth 1 -maxdepth 1 -type l)

  now=$(date +%s)
  for owner in "${!targets[@]}"; do
    printf '%s\t%s\n' "${mtimes[$owner]}" "$owner"
  done | sort -n | while IFS=$'\t' read -r mtime owner; do
    kb=$(printf '%s' "${targets[$owner]}" | xargs -r nix-store --query --requisites 2>/dev/null | sort -u | store_kb)
    ((kb >= MIN_KB)) || continue
    row "$(human "$kb")" "$(pretty "$owner") ($(((now - mtime) / 86400))d old)" "rm -rf $(pretty "$owner")"
  done
  echo "  then: nix-collect-garbage"
}

reclaimable() {
  {
    candidate_path "$HOME/.local/share/Trash" "trash-empty"
    candidate_path "$HOME/.gradle/caches"
    candidate_path "$HOME/.gradle/wrapper/dists"
    candidate_path "$HOME/.npm/_cacache" "npm cache clean --force"
    candidate_path "$HOME/.m2/repository"
    candidate_path "$HOME/.cargo/registry"
    candidate_path "$HOME/go/pkg/mod" "go clean -modcache"
    candidate_path "$HOME/.local/share/pnpm/store" "pnpm store prune"
    candidate_path "$HOME/.local/share/containers" "podman system prune -a"
    candidate_children "$HOME/.cache"

    case "$(uname -s)" in
      Darwin)
        candidate_path "$HOME/.Trash" "rm -rf ~/.Trash/*"
        candidate_path "$HOME/Library/pnpm/store" "pnpm store prune"
        candidate_path "$HOME/Library/Developer/Xcode/DerivedData"
        candidate_path "$HOME/Library/Developer/Xcode/iOS DeviceSupport"
        candidate_path "$HOME/Library/Developer/CoreSimulator" "xcrun simctl delete unavailable"
        candidate_path "$HOME/Library/Containers/com.docker.docker" "docker system prune -a"
        candidate_children "$HOME/Library/Caches"
        ;;
      Linux)
        candidate "$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[KMGT]' | numfmt --from=iec --to-unit=1024 || echo 0)" \
          "systemd journal" "sudo journalctl --vacuum-time=2weeks"
        ;;
    esac
  } | sort -t$'\t' -k1,1nr | while IFS=$'\t' read -r kb label cmd; do
    row "$(human "$kb")" "$label" "$cmd"
  done

  if [[ "$(uname -s)" == Darwin ]]; then
    local snapshots
    snapshots=$(tmutil listlocalsnapshots / 2>/dev/null | grep -c com.apple || true)
    ((snapshots > 0)) && row "$snapshots snaps" "APFS local snapshots (size unknown)" "sudo tmutil thinlocalsnapshots / 999999999999 4"
  fi
  return 0
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Every section is dominated by I/O and independent of the others, so they run
# concurrently and are printed in order as they finish.
nix_store >"$tmp/nix_store" &
nix_store_pid=$!
dev_shells >"$tmp/dev_shells" &
dev_shells_pid=$!
reclaimable >"$tmp/reclaimable" &
reclaimable_pid=$!
{ dust -P -d 3 -n 20 "$HOME" 2>/dev/null || true; } >"$tmp/home" &
home_pid=$!

show() {
  section "$1"
  wait "$2" || true
  cat "$3"
}

section "Free space"
# On macOS /, /nix and ~ are volumes of one APFS container with identical
# numbers; collapse them to one line.
df -h / /nix "$HOME" 2>/dev/null | awk 'NR == 1 || !seen[$2 $3 $4]++'

show "Reclaimable (largest first)" "$reclaimable_pid" "$tmp/reclaimable"
show "Nix store" "$nix_store_pid" "$tmp/nix_store"
show "Dev shells and build results pinning the store (oldest first; closures overlap)" "$dev_shells_pid" "$tmp/dev_shells"
show "Largest in ~ (not all reclaimable)" "$home_pid" "$tmp/home"

section "Dig deeper"
echo "  gdu ~           browse and delete interactively"
echo "  nix-tree        why a store path is alive and what it costs"
echo "  dust <dir>      tree of any directory"
