#!/usr/bin/env bash

set -euo pipefail

# Bootstrap NixOS with nixos-anywhere and disko
# Usage: ./bootstrap.sh <username> <hostname>

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    local username="$1"
    local hostname="$2"
    
    log_info "Checking prerequisites..."
    
    local missing_deps=()
    
    # Check for required commands
    local required_commands=("ssh" "ssh-keygen" "ssh-copy-id" "scp" "pass" "nix" "mktemp")
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install the missing dependencies and try again."
        exit 1
    fi
    
    # Check if we're in a nix flake directory
    if [[ ! -f "flake.nix" ]]; then
        log_error "flake.nix not found. Please run this script from your nix-config directory."
        exit 1
    fi
    
    # Check if FLAKE_DIR is set, if not set it to current directory
    if [[ -z "${FLAKE_DIR:-}" ]]; then
        export FLAKE_DIR="$(pwd)"
        log_info "FLAKE_DIR set to: $FLAKE_DIR"
    fi
    
    # Check SSH connectivity and passwordless sudo    
    log_info "Checking SH connectivity and passwordless sudo for $username@$hostname..."
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$username@$hostname" "sudo -n true" 2>/dev/null; then
        log_error "Passwordless sudo is not configured for $username@$hostname"
        log_error "Please ensure:"
        log_error "1. User $username is added to sudo group: sudo usermod -aG sudo $username"
        log_error "2. Passwordless sudo is configured:"
        log_error "   - Run: sudo visudo"
        log_error "   - Add: $username ALL=(ALL) NOPASSWD: ALL"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Function to validate parameters
validate_parameters() {
    if [[ $# -ne 2 ]]; then
        log_error "Usage: $0 <username> <hostname>"
        log_error "  username: Target user to create on the host"
        log_error "  hostname: Target hostname or IP address"
        exit 1
    fi
    
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
    
    # Check if hostname is reachable
    log_info "Checking if $hostname is reachable..."
    if ! ping -c 1 -W 5 "$hostname" >/dev/null 2>&1; then
        log_warning "Host $hostname is not reachable via ping. Continuing anyway..."
    else
        log_success "Host $hostname is reachable"
    fi
}

# Function to setup SSH host keys (generate new or retrieve existing from pass)
setup_ssh_keys() {
    local hostname="$1"
    
    log_info "Setting up SSH host keys for $hostname..."
    
    # Create temporary directory for keys with proper structure for nixos-anywhere
    local keysdir
    keysdir=$(mktemp -d)
    
    # Create etc/ssh directory structure so keys end up in /etc/ssh on target
    mkdir -p "$keysdir/etc/ssh"
    cd "$keysdir/etc/ssh"
    
    log_info "Keys directory: $keysdir"
    
    # Check if SSH keys already exist in pass
    local private_key_path="Infra/Host/$hostname/ssh_host_ed25519_key"
    local public_key_path="Infra/Host/$hostname/ssh_host_ed25519_key.pub"
    
    if pass file get "$private_key_path" >/dev/null 2>&1 && pass file get "$public_key_path" >/dev/null 2>&1; then
        log_info "Found existing SSH keys in pass, retrieving them..."
        
        # Retrieve existing keys from pass
        if ! pass file get "$private_key_path" ssh_host_ed25519_key; then
            log_error "Failed to retrieve private key from pass"
            rm -rf "$keysdir"
            exit 1
        fi
        
        if ! pass file get "$public_key_path" ssh_host_ed25519_key.pub; then
            log_error "Failed to retrieve public key from pass"
            rm -rf "$keysdir"
            exit 1
        fi
        
        log_success "SSH keys retrieved from pass successfully"
    else
        log_info "No existing SSH keys found in pass, generating new ones..."
        
        # Generate SSH key pair
        ssh-keygen -t ed25519 -f ssh_host_ed25519_key -C "root@$hostname" -N ""
        
        if [[ ! -f "ssh_host_ed25519_key" ]] || [[ ! -f "ssh_host_ed25519_key.pub" ]]; then
            log_error "Failed to generate SSH keys"
            rm -rf "$keysdir"
            exit 1
        fi
        
        log_success "SSH keys generated successfully"
    fi
    
    # Set proper permissions
    chmod 600 ssh_host_ed25519_key
    chmod 644 ssh_host_ed25519_key.pub
    
    echo "$keysdir"
}

# Function to backup SSH keys with pass (only if newly generated)
backup_ssh_keys() {
    local keysdir="$1"
    local hostname="$2"
    
    cd "$keysdir/etc/ssh"
    
    # Check if SSH keys already exist in pass
    local private_key_path="Infra/Host/$hostname/ssh_host_ed25519_key"
    local public_key_path="Infra/Host/$hostname/ssh_host_ed25519_key.pub"
    
    if pass file get "$private_key_path" >/dev/null 2>&1 && pass file get "$public_key_path" >/dev/null 2>&1; then
        log_info "SSH keys already exist in pass, skipping backup"
        return 0
    fi
    
    log_info "Backing up newly generated SSH keys with pass..."
    
    # Backup private key
    if ! pass file add ssh_host_ed25519_key "$private_key_path"; then
        log_error "Failed to backup private key with pass"
        exit 1
    fi
    
    # Backup public key
    if ! pass file add ssh_host_ed25519_key.pub "$public_key_path"; then
        log_error "Failed to backup public key with pass"
        exit 1
    fi
    
    # Push to git if possible
    if pass git push 2>/dev/null; then
        log_success "SSH keys backed up and pushed to git"
    else
        log_warning "SSH keys backed up but failed to push to git"
    fi
}

# Function to update known_hosts
update_known_hosts() {
    local hostname="$1"
    
    log_info "Updating known_hosts..."
    
    # Remove old entries
    ssh-keygen -R "$hostname" 2>/dev/null || true
    
    log_info "Please accept the new host key when prompted"
    ssh -o StrictHostKeyChecking=ask "$hostname" exit || true
    
    log_success "known_hosts updated"
}

# Function to generate age keys and update SOPS
setup_age_keys() {
    local keysdir="$1"
    local hostname="$2"
    
    log_info "Generating age keys and updating SOPS..."
    
    cd "$keysdir/etc/ssh"
    
    # Generate age key from SSH public key
    local age_key
    if ! command_exists ssh-to-age; then
        log_info "Installing ssh-to-age..."
        age_key=$(nix-shell -p ssh-to-age --run "cat ssh_host_ed25519_key.pub | ssh-to-age")
    else
        age_key=$(cat ssh_host_ed25519_key.pub | ssh-to-age)
    fi
    
    if [[ -z "$age_key" ]]; then
        log_error "Failed to generate age key"
        exit 1
    fi
    
    log_info "Generated age key: $age_key"
    log_warning "Please add the following age key to your .sops.yaml file:"
    log_warning "  - &$hostname $age_key"
    log_warning "Then update your secrets files with: sops updatekeys ./modules/nixos/secrets.yaml"
    
    read -p "Press Enter when you have updated .sops.yaml and secrets files..."
    
    log_success "Age keys setup completed"
}

# Function to setup all secrets (SSH keys, backup, and age keys)
setup_secrets() {
    local username="$1"
    local hostname="$2"
    
    log_info "Setting up secrets for $hostname..."
    
    # Setup SSH keys (generate new or retrieve existing)
    local keysdir
    keysdir=$(setup_ssh_keys "$hostname")
    
    # Backup SSH keys to pass (only if newly generated)
    backup_ssh_keys "$keysdir" "$hostname"
    
    # Setup age keys and SOPS
    setup_age_keys "$keysdir" "$hostname"
    
    log_success "Secrets setup completed"
    echo "$keysdir"
}

# Function to run nixos-anywhere
run_nixos_anywhere() {
    local keysdir="$1"
    local username="$2"
    local hostname="$3"
    
    log_info "Running nixos-anywhere..."
    
    cd "$FLAKE_DIR"
    
    # Create disk encryption key (you may want to customize this)
    local disk_key="/tmp/disk.key"
    if [[ ! -f "$disk_key" ]]; then
        log_info "Creating disk encryption key..."
        openssl rand -base64 32 > "$disk_key"
        chmod 600 "$disk_key"
    fi
    
    log_info "Starting nixos-anywhere installation..."
    log_warning "This may take a while..."
    
    if ! nix run github:nix-community/nixos-anywhere -- \
        --disko-mode disko \
        --disk-encryption-keys /tmp/disk.key "$disk_key" \
        --extra-files "$keysdir" \
        --flake ".#$hostname" \
        "$username@$hostname"; then
        log_error "nixos-anywhere installation failed"
        exit 1
    fi
    
    log_success "NixOS installation completed successfully!"
}

# Function to cleanup
cleanup() {
    local keysdir="$1"
    
    log_info "Cleaning up..."
    
    # Remove temporary keys directory
    if [[ -n "$keysdir" ]] && [[ -d "$keysdir" ]]; then
        rm -rf "$keysdir"
        log_success "Temporary keys directory removed"
    fi
    
    # Remove disk key
    if [[ -f "/tmp/disk.key" ]]; then
        rm -f "/tmp/disk.key"
        log_success "Disk key removed"
    fi
}

# Main function
main() {
    local username="$1"
    local hostname="$2"
    local keysdir=""
    
    log_info "Starting NixOS bootstrap for $username@$hostname"
    
    # Set up trap for cleanup
    trap 'cleanup "$keysdir"' EXIT
    
    # Check prerequisites
    check_prerequisites "$username" "$hostname"
    
    # Setup all secrets (SSH keys, backup, and age keys)
    keysdir=$(setup_secrets "$username" "$hostname")
    
    # Run nixos-anywhere
    run_nixos_anywhere "$keysdir" "$username" "$hostname"
    
    log_success "Bootstrap completed successfully!"
    log_info "You can now SSH to $username@$hostname to complete any remaining setup"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    validate_parameters "$@"
    main "$@"
fi
