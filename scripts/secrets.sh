#!/usr/bin/env bash

set -euo pipefail

# Secrets setup script for NixOS deployment
# Usage: ./secrets.sh <hostname> [--force]
# Environment variables:
#   AUTO_APPROVE: Skip interactive SOPS update confirmation (set to any value)

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# SSH key constants
readonly SSH_PRIVATE_KEY_NAME="ssh_host_ed25519_key"
readonly SSH_PUBLIC_KEY_NAME="ssh_host_ed25519_key.pub"

# Function to check prerequisites
check_prerequisites() {
    local hostname="$1"
    
    log_info "Checking prerequisites..."
    
    # Check for required commands
    local required_commands=("ssh-keygen" "pass" "nix" "mktemp")
    check_dependencies "${required_commands[@]}"
    
    # Check if we're in a nix flake directory
    check_flake_directory
    
    # Set FLAKE_DIR if not already set
    setup_flake_dir
    
    # Note: SSH connectivity check is not needed for secrets generation
    # The actual SSH connection will be validated during bootstrap phase
    
    log_success "Prerequisites check passed"
}

# Function to validate parameters
validate_parameters() {
    if [[ $# -lt 1 ]]; then
        log_error "Usage: $0 <hostname> [--force]"
        log_error "  hostname: Target hostname or IP address"
        log_error "  --force: Force regeneration of SSH keys even if they exist"
        log_error ""
        log_error "Environment variables:"
        log_error "  AUTO_APPROVE: Skip interactive SOPS update confirmation (set to any value)"
        exit 1
    fi
    
    local hostname="$1"
    
    # Basic validation
    if [[ -z "$hostname" ]]; then
        log_error "Hostname cannot be empty"
        exit 1
    fi
    
    # Check if hostname is reachable
    check_hostname_reachable "$hostname"
}

# Function to setup SSH host keys (generate new or retrieve existing from pass)
# Returns: "new" if keys were newly generated, "existing" if retrieved from pass
setup_ssh_keys() {
    local keysdir="$1"
    local hostname="$2"
    local force_new="$3"
    
    log_info "Setting up SSH host keys for $hostname..."
    
    local ssh_keys_dir="$keysdir/etc/ssh"
    
    # Create etc/ssh directory structure so keys end up in /etc/ssh on target
    mkdir -p "$ssh_keys_dir"
    cd "$ssh_keys_dir"
    
    local pass_key_root="Infra/Host/$hostname/ssh"
    
    # Check if SSH keys already exist in pass and not forcing new keys
    if [[ "$force_new" != "true" ]] && pass file get "$pass_key_root/$SSH_PRIVATE_KEY_NAME" >/dev/null 2>&1 && pass file get "$pass_key_root/$SSH_PUBLIC_KEY_NAME" >/dev/null 2>&1; then
        log_info "Found existing SSH keys in pass, retrieving them..."
        
        # Retrieve existing keys from pass
        if ! pass file get "$pass_key_root/$SSH_PRIVATE_KEY_NAME"; then
            log_error "Failed to retrieve private key from pass"
            rm -rf "$keysdir"
            exit 1
        fi
        
        if ! pass file get "$pass_key_root/$SSH_PUBLIC_KEY_NAME"; then
            log_error "Failed to retrieve public key from pass"
            rm -rf "$keysdir"
            exit 1
        fi
        
        log_success "SSH keys retrieved from pass successfully"
        
        # Set proper permissions
        chmod 600 "$SSH_PRIVATE_KEY_NAME"
        chmod 644 "$SSH_PUBLIC_KEY_NAME"
        
        echo "existing"
    else
        if [[ "$force_new" == "true" ]]; then
            log_info "Forcing generation of new SSH keys..."
        else
            log_info "No existing SSH keys found in pass, generating new ones..."
        fi
        
        # Generate SSH key pair
        ssh-keygen -t ed25519 -f "$ssh_keys_dir/$SSH_PRIVATE_KEY_NAME" -C "root@$hostname" -N ""
        
        if [[ ! -f "$ssh_keys_dir/$SSH_PRIVATE_KEY_NAME" ]] || [[ ! -f "$ssh_keys_dir/$SSH_PUBLIC_KEY_NAME" ]]; then
            log_error "Failed to generate SSH keys"
            rm -rf "$keysdir"
            exit 1
        fi
        
        log_success "SSH keys generated successfully"
        
        # Set proper permissions
        chmod 600 "$SSH_PRIVATE_KEY_NAME"
        chmod 644 "$SSH_PUBLIC_KEY_NAME"
        
        # Backup newly generated SSH keys to pass
        log_info "Backing up newly generated SSH keys with pass..."
        
        # Backup private key
        if ! pass file add "$ssh_keys_dir/$SSH_PRIVATE_KEY_NAME" "$pass_key_root"; then
            log_error "Failed to backup private key with pass"
            exit 1
        fi
        
        # Backup public key
        if ! pass file add "$ssh_keys_dir/$SSH_PUBLIC_KEY_NAME" "$pass_key_root"; then
            log_error "Failed to backup public key with pass"
            exit 1
        fi
        
        # Push to git if possible
        if pass git push 2>/dev/null; then
            log_success "SSH keys backed up and pushed to git"
        else
            log_warning "SSH keys backed up but failed to push to git"
        fi
        
        echo "new"
    fi
}

# Function to generate age keys and update SOPS
setup_age_keys() {
    local keysdir="$1"
    local hostname="$2"
    local keys_are_new="$3"
    local ssh_keys_dir="$keysdir/etc/ssh"
    
    log_info "Generating age keys and updating SOPS..."
    
    # Generate age key from SSH public key
    local age_key
    if ! command_exists ssh-to-age; then
        log_info "Installing ssh-to-age..."
        age_key=$(nix-shell -p ssh-to-age --run "cat \"$ssh_keys_dir/$SSH_PUBLIC_KEY_NAME\" | ssh-to-age")
    else
        age_key=$(cat "$ssh_keys_dir/$SSH_PUBLIC_KEY_NAME" | ssh-to-age)
    fi
    
    if [[ -z "$age_key" ]]; then
        log_error "Failed to generate age key"
        exit 1
    fi
    
    log_info "Generated age key: $age_key"
    
    # Only prompt for SOPS updates if keys are newly generated
    if [[ "$keys_are_new" == "new" ]]; then
        log_warning "Please add the following age key to your .sops.yaml file:"
        log_warning "  - &$hostname $age_key"
        log_warning "Then update your secrets files with: sops updatekeys ./modules/nixos/secrets.yaml"
        
        if [[ -z "${AUTO_APPROVE:-}" ]]; then
            read -p "Press Enter when you have updated .sops.yaml and secrets files..."
        else
            log_info "AUTO_APPROVE is set, skipping interactive SOPS update confirmation"
        fi
    else
        log_info "Using existing SSH keys, SOPS configuration should already be up to date"
        log_info "Age key for reference: $age_key"
    fi
    
    log_success "Age keys setup completed"
}

# Function to setup all secrets (SSH keys, backup, and age keys)
setup_secrets() {
    local hostname="$1"
    local force_new="$2"
    
    log_info "Setting up secrets for $hostname..."
    
    # Create temporary directory for keys with proper structure for nixos-anywhere
    local keysdir
    keysdir=$(mktemp -d)    
    
    log_info "Keys directory: $keysdir"
    
    # Setup SSH keys (generate new or retrieve existing, backup if newly generated)
    local keys_status
    keys_status=$(setup_ssh_keys "$keysdir" "$hostname" "$force_new")
    
    # Setup age keys and SOPS
    setup_age_keys "$keysdir" "$hostname" "$keys_status"
    
    log_success "Secrets setup completed"
    echo "$keysdir"
}

# Function to cleanup
cleanup() {
    local keysdir="$1"
    cleanup_temp_dir "$keysdir"
}

# Main function
main() {
    local hostname="$1"
    local force_new="false"
    
    # Check for --force flag
    if [[ "${2:-}" == "--force" ]]; then
        force_new="true"
        log_info "Force mode enabled - will regenerate SSH keys even if they exist"
    fi
    
    log_info "Setting up secrets for $hostname..."
    
    local keysdir=""
    
    # Set up trap for cleanup
    trap 'cleanup "$keysdir"' EXIT
    
    # Check prerequisites
    check_prerequisites "$hostname"
    
    # Setup all secrets (SSH keys, backup, and age keys)
    keysdir=$(setup_secrets "$hostname" "$force_new")
    
    log_success "Secrets setup completed successfully!"
    log_info "Keys directory: $keysdir"
    log_info "You can now run deploy.sh with this keys directory"
    
    # Don't cleanup on success - return the keysdir for deploy.sh to use
    trap - EXIT
    echo "KEYSDIR=$keysdir"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    validate_parameters "$@"
    main "$@"
fi
