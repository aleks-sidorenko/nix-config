#!/usr/bin/env bash
# Exposes the common.sh log helpers to one-line just recipes, which cannot
# source a file across lines.
# Usage: log.sh <info|success|warning|error> <message>
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$SCRIPT_DIR/common.sh"

case "${1:-}" in
    info | success | warning | error) "log_$1" "${2:-}" ;;
    *) log_error "log.sh: unknown level '${1:-}' (use info, success, warning, error)"; exit 2 ;;
esac
