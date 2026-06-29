#!/usr/bin/env bash
# Self-contained test runner for media-tools.
# Run inside a nix shell that provides exiftool + coreutils + findutils:
#   nix shell nixpkgs#exiftool nixpkgs#coreutils nixpkgs#findutils \
#     --command bash packages/media-tools/test/run-tests.sh
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$TEST_DIR/.." && pwd)"
# shellcheck source=../media-common.sh
source "$LIB_DIR/media-common.sh"

PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "ok   - $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL - $desc"
    echo "         expected: [$expected]"
    echo "         actual:   [$actual]"
    FAIL=$((FAIL + 1))
  fi
}

# Tests are appended below by later tasks.

finish() {
  echo "----------------------------------------"
  echo "PASS: $PASS  FAIL: $FAIL"
  [[ "$FAIL" -eq 0 ]]
}
