#!/usr/bin/env bash

# Common utilities for NixOS bootstrap scripts
# This file should be sourced by other scripts, not executed directly

# Ensure this file is only sourced once
if [[ -n "${_COMMON_SH_LOADED:-}" ]]; then
    return 0
fi
_COMMON_SH_LOADED=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
#
# All logs go to stderr so that scripts can return data on stdout via
# command substitution (e.g. `keysdir=$(setup_secrets ...)`) without the log
# lines contaminating the captured value. This is what keeps the age key and
# other prompts visible when `just bootstrap-secrets` runs the script inside
# `$(... | tail -1)`.
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if we're in a nix flake directory
check_flake_directory() {
    if [[ ! -f "flake.nix" ]]; then
        log_error "flake.nix not found. Please run this script from your nix-config directory."
        exit 1
    fi
}

# Function to set FLAKE_DIR if not already set
setup_flake_dir() {
    if [[ -z "${FLAKE_DIR:-}" ]]; then
        export FLAKE_DIR="$(pwd)"
        log_info "FLAKE_DIR set to: $FLAKE_DIR"
    fi
}

# Function to validate basic parameters (username and hostname)
validate_basic_parameters() {
    local username="$1"
    local hostname="$2"
    
    # Basic validation
    if [[ -z "$username" ]]; then
        log_error "Username cannot be empty"
        exit 1
    fi
    
    if [[ -z "$hostname" ]]; then
        log_error "Hostname cannot be empty"
        exit 1
    fi
}

# Function to check if hostname is reachable
check_hostname_reachable() {
    local hostname="$1"
    
    log_info "Checking if $hostname is reachable..."
    if ! ping -c 1 -W 5 "$hostname" >/dev/null 2>&1; then
        log_warning "Host $hostname is not reachable via ping. Continuing anyway..."
    else
        log_success "Host $hostname is reachable"
    fi
}

# Function to check for missing dependencies
check_dependencies() {
    local dependencies=("$@")
    local missing_deps=()
    
    for cmd in "${dependencies[@]}"; do
        if ! command_exists "$cmd"; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install the missing dependencies and try again."
        exit 1
    fi
}

# Function to check SSH connectivity
check_ssh_connectivity() {
    local username="$1"
    local hostname="$2"
    local check_sudo="${3:-true}"
    
    if [[ "$check_sudo" == "true" ]]; then
        log_info "Checking SSH connectivity and passwordless sudo for $username@$hostname..."
        if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$username@$hostname" "sudo -n true" 2>/dev/null; then
            log_error "Passwordless sudo is not configured for $username@$hostname"
            log_error "Please ensure:"
            log_error "1. User $username is added to sudo group: sudo usermod -aG sudo $username"
            log_error "2. Passwordless sudo is configured:"
            log_error "   - Run: sudo visudo"
            log_error "   - Add: $username ALL=(ALL) NOPASSWD: ALL"
            exit 1
        fi
    else
        log_info "Checking SSH connectivity to $username@$hostname..."
        if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$username@$hostname" "echo 'SSH connection successful'" 2>/dev/null; then
            log_error "Cannot connect to $username@$hostname via SSH"
            log_error "Please ensure SSH access is configured"
            exit 1
        fi
    fi
}

# Function to cleanup temporary directories
cleanup_temp_dir() {
    local temp_dir="$1"
    
    if [[ -n "$temp_dir" ]] && [[ -d "$temp_dir" ]]; then
        log_info "Cleaning up temporary directory: $temp_dir"
        rm -rf "$temp_dir"
        log_success "Temporary directory removed"
    fi
}
