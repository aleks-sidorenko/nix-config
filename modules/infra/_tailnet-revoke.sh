# Delete a host's devices from the tailnet.
# Usage: tailnet-revoke <host> [--dry-run|--apply]
#
# Authenticates with the tailscale provider's OAuth client, exported by the
# prelude the package prepends. Deleting needs its devices:core write scope; a
# 403 means the client lacks it.

log_info() { echo "[INFO] $1" >&2; }
log_success() { echo "[SUCCESS] $1" >&2; }
log_error() { echo "[ERROR] $1" >&2; }

# Typed confirmation; refuses to guess without a terminal.
confirm() {
    local word="$1" prompt="$2" reply
    if [ ! -t 0 ]; then
        log_error "Confirmation required (expected '$word') but stdin is not a terminal — run this interactively"
        exit 1
    fi
    read -rp "$prompt" reply
    [ "$reply" = "$word" ]
}

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    log_error "Usage: tailnet-revoke <host> [--dry-run|--apply]"
    exit 1
fi

host="$1"
mode="${2:---dry-run}"
api="https://api.tailscale.com/api/v2"

case "$mode" in
--dry-run | --apply) ;;
*)
    log_error "Unknown mode '$mode' (expected --dry-run or --apply)"
    exit 1
    ;;
esac

# Pass credentials via stdin and headers to keep them out of argv/ps
token=$(printf 'client_id=%s&client_secret=%s' "$TF_VAR_tailscale_oauth_client_id" "$TF_VAR_tailscale_oauth_client_secret" |
    curl -fsS "$api/oauth/token" --data @- | jq -er .access_token)

auth_header() {
    printf 'Authorization: Bearer %s\n' "$token"
}

devices=$(curl -fsS -H @<(auth_header) "$api/tailnet/-/devices" |
    jq -c --arg host "$host" '[.devices[] | select(.hostname == $host) | {id, name, lastSeen}]')

if [ "$(jq length <<<"$devices")" -eq 0 ]; then
    log_info "No tailnet device has hostname '$host' — nothing to revoke"
    exit 0
fi

log_info "Tailnet devices for '$host':"
jq -r '.[] | "  \(.name)  id=\(.id)  last seen \(.lastSeen)"' <<<"$devices"

if [ "$mode" = "--dry-run" ]; then
    log_info "Dry run — nothing changed. Re-run with --apply."
    exit 0
fi

if ! confirm "$host" "Type '$host' to delete its devices: "; then
    log_error "Aborted"
    exit 1
fi

for id in $(jq -r '.[].id' <<<"$devices"); do
    status=$(curl -sS -o /dev/null -w '%{http_code}' -X DELETE \
        -H @<(auth_header) "$api/device/$id")
    case "$status" in
    200) log_success "Deleted device $id" ;;
    403)
        log_error "Forbidden deleting $id: the OAuth client lacks the devices:core write scope"
        exit 1
        ;;
    *)
        log_error "Deleting $id failed with HTTP $status"
        exit 1
        ;;
    esac
done
