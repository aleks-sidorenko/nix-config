#!/usr/bin/env bash

set -euo pipefail

# NixOS deployment script using nixos-anywhere
# Usage: ./deploy.sh  <username> <hostname> <keysdir> [nixos-anywhere-options...]
# 
# This script uses the keys directory produced by secrets.sh and deploys 
# NixOS to the target host using nixos-anywhere.

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Function to validate parameters
validate_parameters() {
    if [[ $# -lt 3 ]]; then
        log_error "Usage: $0 <username> <hostname> <keysdir> [nixos-anywhere-options...]"        
        log_error "  username: Target username for SSH connection"
        log_error "  hostname: Target hostname or IP address"
        log_error "  keysdir: Directory containing SSH keys and secrets (from secrets.sh)"
        log_error "  nixos-anywhere-options: Additional options to pass to nixos-anywhere"
        log_error ""
        log_error "Examples:"
        log_error "  $0 alexander myserver /tmp/keysXXX"
        log_error "  $0 alexander myserver /tmp/keysXXX --build-on-remote"
        log_error "  $0 alexander myserver /tmp/keysXXX --phases disko"
        log_error "  $0 alexander myserver /tmp/keysXXX --build-on-remote --no-reboot"
        exit 1
    fi
    
    
    local username="$1"
    local hostname="$2"
    local keysdir="$3"
    
    # Validate keysdir
    if [[ ! -d "$keysdir" ]]; then
        log_error "Keys directory does not exist: $keysdir"
        log_error "Please run secrets.sh first to generate the keys directory"
        exit 1
    fi
    
    # Check for required SSH keys
    local ssh_dir="$keysdir/extra/persist/etc/ssh"
    
    if [[ ! -f "$ssh_dir/ssh_host_ed25519_key" ]] || [[ ! -f "$ssh_dir/ssh_host_ed25519_key.pub" ]]; then
        log_error "SSH host keys not found in $ssh_dir"
        log_error "The keys directory appears to be invalid or incomplete"
        exit 1
    fi
    
    # Validate basic parameters
    validate_basic_parameters "$username" "$hostname"
}

# Function to check prerequisites
check_prerequisites() {
    local hostname="$1"
    
    log_info "Checking prerequisites..."
    
    # Check for required commands
    local required_commands=("nixos-anywhere" "nix")
    check_dependencies "${required_commands[@]}"
    
    # Check if we're in a nix flake directory
    check_flake_directory
    
    # Set FLAKE_DIR if not already set
    setup_flake_dir
    
    log_success "Prerequisites check passed"
}


# Function to run nixos-anywhere deployment
run_deployment() {
    local username="$1"
    local hostname="$2"
    local keysdir="$3"
    shift 3  # Remove the first 3 arguments
    local extra_opts=("$@")  # Remaining arguments are nixos-anywhere options
    
    log_info "Starting NixOS deployment to $username@$hostname..."
    log_info "Keys directory: $keysdir"
    
    # Prepare nixos-anywhere command
    local cmd=(
        "nixos-anywhere"
        "--extra-files" "$keysdir/extra"
        "--flake" ".#$hostname"
    )
    
    # Check for disk encryption key and add it if present
    local disk_key_file="$keysdir/disk.key"
    if [[ -f "$disk_key_file" ]]; then
        log_info "Found disk encryption key, adding --disk-encryption-keys option"
        cmd+=("--disk-encryption-keys" "/tmp/disk.key" "$disk_key_file")
    fi
    
    # Add any extra options passed to this script
    if [[ ${#extra_opts[@]} -gt 0 ]]; then
        log_info "Additional nixos-anywhere options: ${extra_opts[*]}"
        cmd+=("${extra_opts[@]}")
    fi
    
    SHELL=$(which bash)

    # Add the target
    cmd+=("$username@$hostname")
    
    log_info "Running command: ${cmd[*]}"
    log_info "Starting deployment (this may take a while)..."
    
    # Run the deployment
    if "${cmd[@]}"; then
        log_success "NixOS deployment completed successfully!"        
    else
        log_error "NixOS deployment failed!"
        log_error "Check the output above for error details"
        exit 1
    fi
}

# Function to cleanup (if needed)
cleanup() {
    # Currently no cleanup needed as we don't create temporary files
    # The keysdir is managed by secrets.sh and should be cleaned up there
    :
}

# Main function
main() {    
    local username="$1"
    local hostname="$2"
    local keysdir="$3"

    shift 3
    local extra_opts=("$@")
    
    log_info "Starting NixOS deployment using nixos-anywhere..."
    log_info "Target: $username@$hostname"
    log_info "Keys directory: $keysdir"
    
    # Set up trap for cleanup
    trap cleanup EXIT
    
    # Check prerequisites
    check_prerequisites "$hostname"
    
    # Check SSH connectivity
    check_ssh_connectivity "$username" "$hostname"
    
    # Run the deployment
    run_deployment "$username" "$hostname" "$keysdir" "${extra_opts[@]}"
    
    log_success "Deployment process completed successfully!"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    validate_parameters "$@"
    main "$@"
fi
