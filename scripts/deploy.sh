#!/usr/bin/env bash

set -euo pipefail

# Bootstrap NixOS with nixos-anywhere and disko
# Usage: ./deploy.sh <keysdir> <username> <hostname> [disk_password] [nixos_anywhere_options...]
# Environment variables:
#   NIXOS_ANYWHERE_OPTS: Additional options to pass to nixos-anywhere
#
# Note: This script focuses only on running nixos-anywhere. 
# Use secrets.sh first to prepare SSH keys and secrets.

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Function to check prerequisites
check_prerequisites() {
    local keysdir="$1"
    local username="$2"
    local hostname="$3"
    
    log_info "Checking prerequisites..."
    
    # Check for required commands
    local required_commands=("ssh" "nix")
    check_dependencies "${required_commands[@]}"
    
    # Check if we're in a nix flake directory
    check_flake_directory
    
    # Set FLAKE_DIR if not already set
    setup_flake_dir
    
    # Check if keys directory exists and contains required files
    if [[ ! -d "$keysdir" ]]; then
        log_error "Keys directory $keysdir does not exist"
        log_error "Please run secrets.sh first to prepare SSH keys and secrets"
        exit 1
    fi
    
    if [[ ! -f "$keysdir/etc/ssh/ssh_host_ed25519_key" ]] || [[ ! -f "$keysdir/etc/ssh/ssh_host_ed25519_key.pub" ]]; then
        log_error "SSH keys not found in $keysdir/etc/ssh/"
        log_error "Please run secrets.sh first to prepare SSH keys and secrets"
        exit 1
    fi
    
    # Check SSH connectivity (basic connectivity test)
    check_ssh_connectivity "$username" "$hostname" false
    
    log_success "Prerequisites check passed"
}

# Function to validate parameters
validate_parameters() {
    if [[ $# -lt 3 ]]; then
        log_error "Usage: $0 <keysdir> <username> <hostname> [disk_password] [nixos_anywhere_options...]"
        log_error "  keysdir: Directory containing SSH keys (created by secrets.sh)"
        log_error "  username: Target user to create on the host"
        log_error "  hostname: Target hostname or IP address"
        log_error "  disk_password: Optional disk encryption password (if not provided, no LUKS encryption)"
        log_error "  nixos_anywhere_options: Additional options to pass to nixos-anywhere"
        log_error ""
        log_error "Environment variables:"
        log_error "  NIXOS_ANYWHERE_OPTS: Additional options to pass to nixos-anywhere"
        log_error ""
        log_error "Note: Run secrets.sh first to prepare SSH keys and secrets"
        exit 1
    fi
    
    local keysdir="$1"
    local username="$2"
    local hostname="$3"
    
    # Basic validation
    if [[ -z "$keysdir" ]]; then
        log_error "Keys directory cannot be empty"
        exit 1
    fi
    
    # Validate username and hostname
    validate_basic_parameters "$username" "$hostname"
    
    # Check if hostname is reachable
    check_hostname_reachable "$hostname"
}


# Function to run nixos-anywhere
run_nixos_anywhere() {
    local keysdir="$1"
    local username="$2"
    local hostname="$3"
    local disk_password="${4:-}"
    shift 4  # Remove the first 4 arguments, remaining are additional nixos-anywhere options
    local additional_opts=("$@")
    
    log_info "Running nixos-anywhere..."
    
    cd "$FLAKE_DIR"
    
    # Start with base arguments
    local nixos_anywhere_args=(
        --disko-mode disko
        --extra-files "$keysdir"
    )
    
    # Add environment variable options if set
    if [[ -n "${NIXOS_ANYWHERE_OPTS:-}" ]]; then
        log_info "Adding options from NIXOS_ANYWHERE_OPTS: $NIXOS_ANYWHERE_OPTS"
        # Split the options and add them to the array
        read -ra env_opts <<< "$NIXOS_ANYWHERE_OPTS"
        nixos_anywhere_args+=("${env_opts[@]}")
    fi
    
    # Add additional options passed as arguments
    if [[ ${#additional_opts[@]} -gt 0 ]]; then
        log_info "Adding additional options: ${additional_opts[*]}"
        nixos_anywhere_args+=("${additional_opts[@]}")
    fi
    
    if [[ -n "$disk_password" ]]; then
        log_info "Setting up disk encryption with provided password..."
        local disk_key="/tmp/disk.key"
        echo -n "$disk_password" > "$disk_key"
        chmod 600 "$disk_key"
        
        # Add encryption arguments
        nixos_anywhere_args+=(
            --disk-encryption-keys /tmp/disk.key "$disk_key"
        )
        
        log_success "Disk encryption configured"
    else
        log_info "No disk encryption password provided - installing without LUKS encryption"
    fi
    
    # Add flake and target host at the end
    nixos_anywhere_args+=(
        --flake ".#$hostname"
        "$username@$hostname"
    )
    
    log_info "Starting nixos-anywhere installation..."
    log_info "Command: nix run github:nix-community/nixos-anywhere -- ${nixos_anywhere_args[*]}"
    log_warning "This may take a while..."
    
    if ! nix run github:nix-community/nixos-anywhere -- "${nixos_anywhere_args[@]}"; then
        log_error "nixos-anywhere installation failed"
        exit 1
    fi
    
    log_success "NixOS installation completed successfully!"
    
    if [[ -n "$disk_password" ]]; then
        log_info "Post-installation notes for encrypted system:"
        log_info "1. Your system is encrypted and will prompt for the password during boot"
        log_info "2. To set up FIDO2 hardware token for automatic unlocking:"
        log_info "   - Enroll your token: systemd-cryptenroll --fido2-device=auto /dev/disk/by-label/<device>"
        log_info "   - Test the token: systemd-cryptenroll --fido2-device=list /dev/disk/by-label/<device>"
        log_info "3. The FIDO2 configuration is already enabled in your NixOS config"
    else
        log_info "System installed without disk encryption"
    fi
}

# Function to cleanup
cleanup() {
    local keysdir="$1"
    
    log_info "Cleaning up..."
    
    # Remove temporary keys directory
    cleanup_temp_dir "$keysdir"
    
    # Remove disk key
    if [[ -f "/tmp/disk.key" ]]; then
        rm -f "/tmp/disk.key"
        log_success "Disk key removed"
    fi
}

# Main function
main() {
    local keysdir="$1"
    local username="$2"
    local hostname="$3"
    local disk_password="${4:-}"
    shift 4  # Remove the first 4 arguments
    # Check if the next argument looks like a nixos-anywhere option (starts with -)
    # If not, it might be a disk password that was passed as the 5th argument
    if [[ $# -gt 0 && "$1" != -* && -z "$disk_password" ]]; then
        disk_password="$1"
        shift
    fi
    local additional_opts=("$@")
    
    if [[ -n "$disk_password" ]]; then
        log_info "Starting NixOS bootstrap for $username@$hostname with disk encryption"
    else
        log_info "Starting NixOS bootstrap for $username@$hostname without disk encryption"
    fi
    
    # Set up trap for cleanup
    trap 'cleanup "$keysdir"' EXIT
    
    # Check prerequisites
    check_prerequisites "$keysdir" "$username" "$hostname"
    
    # Run nixos-anywhere
    run_nixos_anywhere "$keysdir" "$username" "$hostname" "$disk_password" "${additional_opts[@]}"
    
    log_success "Bootstrap completed successfully!"
    log_info "You can now SSH to $username@$hostname to complete any remaining setup"
    
    if [[ -n "$disk_password" ]]; then
        log_info "Remember: Your disk is encrypted. You'll need the password to unlock it on boot."
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    validate_parameters "$@"
    main "$@"
fi
