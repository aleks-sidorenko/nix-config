# Shared by our scripts. Messages go to stderr, so stdout stays the output.

log() {
    echo "$*" >&2
}

warn() {
    # A wrapped script runs as .<name>-wrapped.
    local name="${0##*/}"
    name="${name#.}"
    log "${name%-wrapped}: $*"
}

die() {
    warn "$@"
    exit 1
}

# Typing a name back catches the wrong target, which a yes/no does not.
confirm() {
    local message="$1" expected="$2" answer
    log "$message"
    read -r -p "Type '$expected' to continue: " answer
    [ "$answer" = "$expected" ] || die "not confirmed"
}
