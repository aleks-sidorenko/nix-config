#!/usr/bin/env bash

set -euo pipefail

# macOS (nix-darwin) bootstrap script
# Usage: ./bootstrap-darwin.sh <hostname>
#
# Unlike NixOS, macOS has no nixos-anywhere-style remote install: this script
# runs *on the new Mac itself* and brings it from a stock install to a working
# nix-darwin configuration. It is idempotent — safe to re-run — and pauses at
# the one manual gate (registering the host as a SOPS recipient), mirroring the
# NixOS bootstrap-secrets step.
#
# Environment variables:
#   AUTO_APPROVE   Skip the interactive SOPS-registration pause (set to any value)
#   NIX_INSTALLER  Override the Nix install command (advanced)

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

readonly SSH_HOST_PUBKEY="/etc/ssh/ssh_host_ed25519_key.pub"

# Function to validate parameters
validate_parameters() {
    if [[ $# -lt 1 ]]; then
        log_error "Usage: $0 <hostname>"
        log_error "  hostname: the darwinConfigurations attribute for this Mac (e.g. workbook)"
        log_error ""
        log_error "Environment variables:"
        log_error "  AUTO_APPROVE: Skip the interactive SOPS-registration pause (set to any value)"
        exit 1
    fi

    local hostname="$1"

    if [[ -z "$hostname" ]]; then
        log_error "Hostname cannot be empty"
        exit 1
    fi

    if [[ "$(uname -s)" != "Darwin" ]]; then
        log_error "This script must run on the target macOS host."
        exit 1
    fi
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check for required commands (curl drives the Homebrew/Nix installers).
    local required_commands=("curl" "uname")
    check_dependencies "${required_commands[@]}"

    # Check if we're in a nix flake directory
    check_flake_directory

    # Set FLAKE_DIR if not already set
    setup_flake_dir

    log_success "Prerequisites check passed"
}

# Xcode Command Line Tools give us `git` (needed to evaluate the flake) and the
# compiler toolchain Homebrew/Nix rely on.
install_xcode_clt() {
    if xcode-select -p >/dev/null 2>&1; then
        log_success "Xcode Command Line Tools already installed"
        return 0
    fi

    log_info "Installing Xcode Command Line Tools..."
    xcode-select --install || true
    log_warning "A GUI installer was launched. Complete it, then re-run this script."
    exit 0
}

# nix-darwin's homebrew module manages the Brewfile but does NOT install Homebrew
# itself — brew must exist first, or the first activation fails.
install_homebrew() {
    if command_exists brew; then
        log_success "Homebrew already installed"
        return 0
    fi

    log_info "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Make brew available for the rest of this run (Apple Silicon vs Intel path).
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    log_success "Homebrew installed"
}

# Install Nix via the Determinate Systems installer in *upstream* mode (no
# --determinate flag): it installs vanilla Nix with far more robust macOS
# uninstall/upgrade handling, while nix-darwin keeps managing the daemon and
# nix.conf (nix.enable = true). See docs/bootstrap.md for the daemon-vs-
# Determinate trade-off.
install_nix() {
    if command_exists nix; then
        log_success "Nix already installed"
        return 0
    fi

    log_info "Installing Nix (Determinate installer, upstream Nix)..."
    if [[ -n "${NIX_INSTALLER:-}" ]]; then
        eval "$NIX_INSTALLER"
    else
        curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
            | sh -s -- install --no-confirm
    fi

    # Load Nix into the current shell so the first switch can run without a
    # re-login.
    # shellcheck disable=SC1091
    if [[ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
        source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    fi

    log_success "Nix installed"
}

# The darwin sops module decrypts secrets with the host's age key, which is
# derived from macOS's own SSH host key. Register that key in .sops.yaml before
# the first switch, or activation fails decrypting the GitHub token. This mirrors
# the NixOS bootstrap-secrets SOPS step (there we generate the key; here macOS
# already has it).
register_sops_recipient() {
    local hostname="$1"

    if [[ ! -f "$SSH_HOST_PUBKEY" ]]; then
        log_warning "$SSH_HOST_PUBKEY not found; enabling Remote Login generates it."
        log_info "Enable it with: sudo systemsetup -setremotelogin on"
        exit 1
    fi

    log_info "Deriving this host's age key from its SSH host key..."
    local age_key
    age_key=$(pubkey_to_age "$SSH_HOST_PUBKEY")

    if [[ -z "$age_key" ]]; then
        log_error "Failed to derive age key from $SSH_HOST_PUBKEY"
        exit 1
    fi

    log_info "Generated age key: $age_key"
    log_warning "Please add the following age key to your .sops.yaml file:"
    log_warning "  - &$hostname $age_key"
    log_warning "Add it under the anchors AND to the darwin (and home) creation_rules,"
    log_warning "then re-encrypt:"
    log_warning "  sops updatekeys modules/darwin/secrets.yaml"
    log_warning "  sops updatekeys modules/home/secrets.yaml"

    if [[ -z "${AUTO_APPROVE:-}" ]]; then
        read -r -p "Press Enter when you have updated .sops.yaml and secrets files..."
    else
        log_info "AUTO_APPROVE is set, skipping the SOPS confirmation"
    fi
}

# Guard mirroring the NixOS bootstrap-deploy check: the host's age key must be
# registered as a SOPS recipient in .sops.yaml, or the first switch boots unable
# to decrypt its secrets (e.g. the GitHub token).
verify_sops_recipient() {
    local hostname="$1"
    local sops_file="${FLAKE_DIR:-.}/.sops.yaml"

    if [[ ! -f "$SSH_HOST_PUBKEY" ]] || [[ ! -f "$sops_file" ]]; then
        log_warning "Cannot verify SOPS recipient (missing host key or .sops.yaml); skipping."
        return 0
    fi

    local host_age
    host_age=$(pubkey_to_age "$SSH_HOST_PUBKEY")
    if [[ -z "$host_age" ]]; then
        log_warning "Could not derive an age key (ssh-to-age unavailable?); skipping SOPS check."
        return 0
    fi

    # Anchor lines look like:  '    - &workbook age1xxxx...'
    local registered_age
    registered_age=$(grep -oE "&${hostname}[[:space:]]+age1[a-z0-9]+" "$sops_file" | grep -oE 'age1[a-z0-9]+' | head -1)

    if [[ "$host_age" != "$registered_age" ]]; then
        log_error "Host '$hostname' is not registered (or mismatched) as a SOPS recipient in $sops_file."
        log_error "  this host's key : $host_age"
        log_error "  registered      : ${registered_age:-<none>}   (&$hostname)"
        log_error "Fix .sops.yaml and run: sops updatekeys modules/darwin/secrets.yaml modules/home/secrets.yaml"
        exit 1
    fi

    log_success "SOPS recipient check passed: &$hostname = $host_age"
}

# Newer Homebrew refuses to load formulae from third-party taps until the tap is
# explicitly trusted (e.g. akeylesslabs/tap). Pre-trust the taps declared in the
# flake so the first `brew bundle` during activation doesn't abort.
trust_homebrew_taps() {
    local hostname="$1"

    log_info "Pre-trusting third-party Homebrew taps declared in the flake..."
    local taps
    taps=$(nix eval --raw \
        ".#darwinConfigurations.$hostname.config.nix-config.system.homebrew.taps" \
        --apply 'ts: builtins.concatStringsSep "\n" ts' 2>/dev/null || true)

    if [[ -z "$taps" ]]; then
        log_info "No taps to trust"
        return 0
    fi

    while IFS= read -r tap; do
        [[ -z "$tap" ]] && continue
        # `brew trust` is a no-op if already trusted; ignore versions without it.
        if brew trust "$tap" >/dev/null 2>&1; then
            log_success "Trusted tap: $tap"
        else
            log_info "Tap '$tap' needs no trust (or this brew has no 'trust' subcommand)"
        fi
    done <<< "$taps"
}

# First nix-darwin activation. `nix run nix-darwin` bootstraps darwin-rebuild
# without it being on PATH yet; subsequent rebuilds use `nh os switch` /
# `darwin-rebuild switch`.
run_first_switch() {
    local hostname="$1"

    log_info "Running the first nix-darwin switch for .#$hostname (needs sudo)..."
    sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ".#$hostname"
    log_success "nix-darwin activated"
}

# Main function
main() {
    local hostname="$1"

    log_info "Bootstrapping macOS host: $hostname"

    check_prerequisites

    install_xcode_clt
    install_homebrew
    install_nix
    register_sops_recipient "$hostname"
    verify_sops_recipient "$hostname"
    trust_homebrew_taps "$hostname"
    run_first_switch "$hostname"

    log_success "macOS bootstrap complete for $hostname!"
    log_info "Manual follow-ups (see docs/bootstrap.md → macOS):"
    log_info "  1. Import your GPG private key and clone the pass store."
    log_info "  2. Open a new shell so fish + the Nix profile are picked up."
    log_info "  3. Subsequent updates: nh os switch"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    validate_parameters "$@"
    main "$@"
fi
