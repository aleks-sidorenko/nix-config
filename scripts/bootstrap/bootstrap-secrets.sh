#!/usr/bin/env bash

set -euo pipefail

# Secrets setup script for NixOS deployment
# Usage: ./secrets.sh <hostname> [--disk-password <password>]
# Environment variables:
#   AUTO_APPROVE: Skip interactive SOPS update confirmation (set to any value)

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

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
        log_error "Usage: $0 <hostname> [--disk-password <password>]"
        log_error "  hostname: Target hostname or IP address"
        log_error "  --disk-password <password>: Use specified password for disk encryption (optional)"
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

# Function to setup SSH host keys (retrieve existing from pass or generate new if none exist)
# Sets the global SSH_KEYS_STATUS to "new" if keys were newly generated, or
# "existing" if retrieved from pass. Status is returned via a global (not stdout)
# so that ssh-keygen / pass output can't contaminate a command-substitution capture.
setup_ssh_keys() {
    local keysdir="$1"
    local hostname="$2"

    log_info "Setting up SSH host keys for $hostname..."

    local ssh_keys_dir="$keysdir/extra/persist/etc/ssh"

    # Create extra/etc/ssh directory structure so keys end up in /etc/ssh on target
    mkdir -p "$ssh_keys_dir"
    cd "$ssh_keys_dir"

    local pass_key_root="infra/host/$hostname/ssh"

    # Check if SSH keys already exist in pass
    if pass file get "$pass_key_root/$SSH_PRIVATE_KEY_NAME" >/dev/null 2>&1 && pass file get "$pass_key_root/$SSH_PUBLIC_KEY_NAME" >/dev/null 2>&1; then
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

        SSH_KEYS_STATUS="existing"
    else
        log_info "No existing SSH keys found in pass, generating new ones..."

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

        SSH_KEYS_STATUS="new"
    fi
}

# Function to generate age keys and update SOPS
setup_age_keys() {
    local keysdir="$1"
    local hostname="$2"
    local keys_are_new="$3"
    local ssh_keys_dir="$keysdir/extra/persist/etc/ssh"

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

    # Always surface the age key and the SOPS step. The host must be a recipient
    # in .sops.yaml before deploy, whether the SSH keys were freshly generated or
    # reused from pass.
    log_warning "Please add the following age key to your .sops.yaml file:"
    log_warning "  - &$hostname $age_key"
    log_warning "Then update your secrets files with: sops updatekeys ./modules/nixos/secrets.yaml"

    if [[ "$keys_are_new" != "new" ]]; then
        log_info "(SSH keys were reused from pass; if this host is already a SOPS recipient, no change is needed.)"
    fi

    if [[ -z "${AUTO_APPROVE:-}" ]]; then
        read -r -p "Press Enter when you have updated .sops.yaml and secrets files..."
    else
        log_info "AUTO_APPROVE is set, skipping interactive SOPS update confirmation"
    fi

    log_success "Age keys setup completed"
}

# Function to setup disk encryption password for disko
setup_disk_password() {
    local keysdir="$1"
    local hostname="$2"
    local disk_password="$3"

    log_info "Setting up disk encryption password for $hostname..."

    local disk_key_file="$keysdir/disk.key"
    local pass_key_path="infra/host/$hostname/disk"

    # Validate password
    if [[ -z "$disk_password" ]]; then
        log_error "Disk password cannot be empty"
        exit 1
    fi

    # Check if disk password already exists in pass
    if pass get "$pass_key_path" >/dev/null 2>&1; then
        log_info "Found existing disk password in pass, using it..."

        # Retrieve existing password from pass and write to disk.key
        if ! pass get "$pass_key_path" > "$disk_key_file"; then
            log_error "Failed to retrieve disk password from pass"
            exit 1
        fi

        log_success "Existing disk password retrieved from pass and written to disk.key"
    else
        log_info "No existing disk password in pass, using provided password and backing up..."

        # Write provided password to disk.key file
        echo -n "$disk_password" > "$disk_key_file"

        if [[ ! -f "$disk_key_file" ]]; then
            log_error "Failed to create disk password file"
            exit 1
        fi

        log_success "Disk password written to file successfully"

        # Backup disk password to pass
        log_info "Backing up disk password with pass..."

        if ! echo -n "$disk_password" | pass insert -f "$pass_key_path"; then
            log_error "Failed to backup disk password with pass"
            exit 1
        fi

        # Push to git if possible
        if pass git push 2>/dev/null; then
            log_success "Disk password backed up and pushed to git"
        else
            log_warning "Disk password backed up but failed to push to git"
        fi
    fi

    # Set proper permissions (read-only for owner)
    chmod 600 "$disk_key_file"

    log_success "Disk password setup completed"
}

# Function to setup all secrets (SSH keys, backup, age keys, and optionally disk password)
setup_secrets() {
    local hostname="$1"
    local disk_password="$2"

    log_info "Setting up secrets for $hostname..."

    # Create temporary directory for keys with proper structure for nixos-anywhere
    local keysdir
    keysdir=$(mktemp -d)

    log_info "Keys directory: $keysdir"

    # Setup SSH keys (generate new or retrieve existing, backup if newly generated).
    # Status comes back via the SSH_KEYS_STATUS global, not stdout, so ssh-keygen /
    # pass chatter can't pollute it.
    setup_ssh_keys "$keysdir" "$hostname"

    # Setup age keys and SOPS
    setup_age_keys "$keysdir" "$hostname" "$SSH_KEYS_STATUS"

    # Setup disk password if provided
    if [[ -n "$disk_password" ]]; then
        setup_disk_password "$keysdir" "$hostname" "$disk_password"
    fi

    log_success "Secrets setup completed"

    # Return the keys directory via a global; the only value written to stdout is
    # the final echo in main(), which the justfile captures via `tail -1`.
    KEYSDIR_RESULT="$keysdir"
}

# Function to cleanup
cleanup() {
    local keysdir="$1"
    cleanup_temp_dir "$keysdir"
}

# Main function
main() {
    local hostname="$1"
    local disk_password=""

    # Parse command line arguments
    shift # Remove hostname from arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --disk-password)
                if [[ $# -lt 2 ]] || [[ "$2" == --* ]]; then
                    log_error "--disk-password requires a password argument"
                    exit 1
                fi
                disk_password="$2"
                log_info "Disk password provided"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    log_info "Setting up secrets for $hostname..."

    local keysdir=""

    # Set up trap for cleanup
    trap 'cleanup "$keysdir"' EXIT

    # Check prerequisites
    check_prerequisites "$hostname"

    # Setup all secrets (SSH keys, backup, age keys, and optionally disk password).
    # setup_secrets returns the path via the KEYSDIR_RESULT global so that command
    # output produced along the way (ssh-keygen, pass, nix-shell) does not end up
    # in the captured keys directory path.
    setup_secrets "$hostname" "$disk_password"
    keysdir="$KEYSDIR_RESULT"

    log_success "Secrets setup completed successfully!"
    log_info "Keys directory: $keysdir"
    if [[ -n "$disk_password" ]]; then
        log_info "Disk encryption password available at: $keysdir/disk.key"
    fi
    log_info "You can now run deploy.sh with this keys directory"

    # Don't cleanup on success - return the keysdir for deploy.sh to use
    trap - EXIT
    echo "$keysdir"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    validate_parameters "$@"
    main "$@"
fi
