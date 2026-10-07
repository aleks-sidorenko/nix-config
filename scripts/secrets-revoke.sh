#!/usr/bin/env bash

set -euo pipefail

# Retire a host's secrets identity — the inverse of bootstrap-secrets, which
# keeps it in two places: the SSH host key pair in pass under
# infra/host/<host>/ (plus a disk password for encrypted hosts), and the age key
# derived from it as the &<host> anchor in .sops.yaml.
# Usage: ./secrets-revoke.sh <host> [--dry-run|--apply]
#
# Environment variables:
#   SOPS_CONFIG         .sops.yaml to edit (default: .sops.yaml)
#   PASSWORD_STORE_DIR  pass store (pass's own variable)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$SCRIPT_DIR/common.sh"

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    log_error "Usage: $0 <host> [--dry-run|--apply]"
    exit 1
fi

host="$1"
mode="${2:---dry-run}"
sops_config="${SOPS_CONFIG:-.sops.yaml}"
pass_root="infra/host/$host"

case "$mode" in
--dry-run | --apply) ;;
*)
    log_error "Unknown mode '$mode' (expected --dry-run or --apply)"
    exit 1
    ;;
esac

check_dependencies yq sops pass git

has_pass_entries() {
    pass ls "$pass_root" >/dev/null 2>&1
}

# Files whose creation rule lists the host as a recipient. sops matches
# path_regex against the file path, so the same match is applied to tracked
# secrets files.
affected_files() {
    local regex
    yq ".creation_rules[] | select(.key_groups[].age[] | alias == \"$host\") | .path_regex" "$sops_config" |
        while read -r regex; do
            git ls-files '*secrets.yaml' '*secrets.yml' | grep -E "$regex" || true
        done | sort -u
}

# Plain assignments, so set -e aborts on a yq failure instead of reading it as
# "no anchor".
anchors=$(yq "[.. | select(anchor == \"$host\")] | length" "$sops_config")
anchor=false
pass_entries=false
[ "$anchors" -gt 0 ] && anchor=true
has_pass_entries && pass_entries=true

if ! $anchor && ! $pass_entries; then
    log_error "Nothing to revoke for '$host': no &$host anchor in $sops_config and no $pass_root in pass"
    exit 1
fi

files=()
if $anchor; then
    files_out=$(affected_files)
    mapfile -t files < <(printf '%s\n' "$files_out" | grep -v '^$' || true)
    if [ ${#files[@]} -eq 0 ]; then
        log_error "&$host anchor exists but no tracked secrets file matches its rules in $sops_config"
        exit 1
    fi
fi

log_info "Revoking secrets identity of '$host'"
if $anchor; then
    log_info "Recipient &$host would be removed from $sops_config and these files are rekeyed."
    log_info "Secrets it could decrypt — rotate any that may be exposed:"
    for f in "${files[@]}"; do
        echo "  $f"
        yq 'del(.sops) | keys | .[]' "$f" | sed 's/^/    /'
    done
else
    log_warning "No &$host anchor in $sops_config; skipping recipients"
fi
if $pass_entries; then
    log_info "Pass entries to remove:"
    pass ls "$pass_root" | sed 's/^/  /'
else
    log_warning "No $pass_root in pass; skipping pass"
fi

if [ "$mode" = "--dry-run" ]; then
    log_info "Dry run — nothing changed. Re-run with --apply."
    exit 0
fi

if ! confirm "$host" "Type '$host' to revoke it: "; then
    log_error "Aborted"
    exit 1
fi

if $anchor; then
    # Use a temp file in the same directory as $sops_config to preserve path_regex
    # resolution. Register a trap to clean up if anything fails.
    tmp="$(dirname "$sops_config")/.sops.yaml.revoke.$$"
    cleanup() { rm -f "$tmp" "$tmp.bak"; }
    trap cleanup EXIT

    cp "$sops_config" "$tmp"

    # Aliases first: deleting the anchor while an alias remains leaves YAML no
    # parser accepts.
    sed -i.bak -E "/^[[:space:]]*- \*${host}[[:space:]]*$/d" "$tmp"
    sed -i.bak -E "/^[[:space:]]*- &${host}[[:space:]]+age1[a-z0-9]+[[:space:]]*$/d" "$tmp"
    rm -f "$tmp.bak"
    remaining=$(yq "[.. | select(anchor == \"$host\" or alias == \"$host\")] | length" "$tmp")
    if [ "$remaining" -ne 0 ]; then
        log_error "$tmp still references $host — its layout is not one anchor/alias per line; .sops.yaml left untouched"
        exit 1
    fi

    # One file at a time: a cold GPG agent failing midway leaves earlier files
    # rekeyed and later ones untouched. A re-run redoes every file (re-rekeying
    # an already-done file is harmless), and .sops.yaml is left untouched until
    # all files rekey successfully.
    for f in "${files[@]}"; do
        log_info "Rekeying $f"
        sops --config "$tmp" updatekeys -y "$f"
    done

    # All files rekeyed successfully; now update the config.
    mv "$tmp" "$sops_config"
    trap - EXIT
    log_success "Recipient &$host removed; ${#files[@]} files rekeyed"
fi

# Last: until every file is rekeyed, this private key is the only way left to
# decrypt the host's files.
if $pass_entries; then
    pass rm -r -f "$pass_root"
    if pass git push 2>/dev/null; then
        log_success "Removed $pass_root from pass and pushed"
    else
        log_warning "Removed $pass_root from pass but failed to push"
    fi
fi
