# justfile for nix-config management
# Run `just --list` to see all available recipes

# Recipe lines run in bash with common.sh's log_* helpers loaded. Status goes
# through them (stderr); help text and listings are the recipe's output and stay
# on stdout with echo. Sourced by the recipe shell itself, never exported: an
# exported BASH_ENV would load common.sh into every bash a recipe starts,
# nixos-anywhere included. Shebang recipes source it themselves.
set shell := ["bash", "-c", "source scripts/common.sh && eval \"$1\"", "just"]

# Default recipe - show help
default:
    @just --list


# Prepare secrets and SSH keys only (Step 1 of bootstrap process)
bootstrap-secrets hostname disk_password="":
    @log_info "Preparing secrets and SSH keys for {{hostname}}..."
    @if [ -n "{{disk_password}}" ]; then \
        KEYSDIR=$(./scripts/bootstrap/bootstrap-secrets.sh "{{hostname}}" --disk-password "{{disk_password}}"); \
    else \
        KEYSDIR=$(./scripts/bootstrap/bootstrap-secrets.sh "{{hostname}}"); \
    fi; \
    log_success "Keys directory: $KEYSDIR"; \
    log_info "To use in next command: set -x KEYSDIR $KEYSDIR"

# Deploy using existing keys directory (Step 2 of bootstrap process)
bootstrap-deploy hostname username="$USER" keysdir="${KEYSDIR:-}" *extra_opts="":
    @log_info "Deploying NixOS to {{username}}@{{hostname}} using keys from {{keysdir}}..."
    @if [ -z "{{keysdir}}" ]; then \
        log_error "No keysdir provided and KEYSDIR environment variable not set"; \
        log_info "Run 'just bootstrap-secrets <hostname>' first, or provide keysdir explicitly"; \
        exit 1; \
    fi
    ./scripts/bootstrap/bootstrap-deploy.sh "{{username}}" "{{hostname}}" "{{keysdir}}" {{extra_opts}}

# Complete bootstrap process (secrets + deploy in one command)
bootstrap hostname username="$USER" disk_password="" *extra_opts="":
    @log_info "Starting complete bootstrap process for {{username}}@{{hostname}}..."
    @if [ -n "${KEYSDIR:-}" ]; then \
        log_info "Using existing KEYSDIR: $KEYSDIR"; \
    elif [ -n "{{disk_password}}" ]; then \
        log_info "Generating secrets with disk password..."; \
        KEYSDIR=$(./scripts/bootstrap/bootstrap-secrets.sh "{{hostname}}" --disk-password "{{disk_password}}"); \
    else \
        log_info "Generating secrets..."; \
        KEYSDIR=$(./scripts/bootstrap/bootstrap-secrets.sh "{{hostname}}"); \
    fi; \
    log_success "Keys directory: $KEYSDIR"; \
    log_info "Proceeding with deployment..."; \
    ./scripts/bootstrap/bootstrap-deploy.sh "{{username}}" "{{hostname}}" "$KEYSDIR" {{extra_opts}}

# Bootstrap a fresh macOS (nix-darwin) host — run ON the target Mac
# Usage: just bootstrap-darwin <hostname>   (e.g. just bootstrap-darwin workbook)
bootstrap-darwin hostname:
    @log_info "Bootstrapping macOS host {{hostname}}..."
    ./scripts/bootstrap/bootstrap-darwin.sh "{{hostname}}"

# Format disks with disko configuration
# Usage:
#   just bootstrap-disk hostname                  # Preview changes (dry-run)
#   just bootstrap-disk hostname --apply          # Apply and format disks
bootstrap-disk hostname mode="--dry-run":
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/common.sh
    log_info "Formatting disks for {{hostname}} using disko..."
    case "{{mode}}" in
    --dry-run)
        log_info "Running in dry-run mode (preview only) — no changes will be made"
        sudo nix run --inputs-from . disko -- --mode disko --flake .#{{hostname}} --dry-run
        ;;
    --apply)
        log_warning "This DESTROYS ALL DATA on the disks configured for {{hostname}}"
        # Typing the host back is the check: a timed window cancels on
        # inattention but not on naming the wrong host, which is the mistake
        # that actually costs a machine.
        if ! confirm {{hostname}} "Type '{{hostname}}' to confirm: "; then
            log_error "Aborted"; exit 1
        fi
        sudo nix run --inputs-from . disko -- --mode disko --flake .#{{hostname}}
        log_success "Disks formatted — run 'just deploy {{hostname}}' to apply mount configuration"
        ;;
    *)
        log_error "Invalid mode: {{mode}}"
        log_error "Use '--dry-run' to preview or '--apply' to format"
        exit 1
        ;;
    esac

# Deploy to a specific host using deploy-rs (or router-import for router)
# Usage:
#   just deploy hostname                            # Deploy with local build
#   just deploy hostname --remote-build             # Deploy with remote build
#   just deploy hostname --dry-run                  # Local build with dry-run
#   just deploy hostname --remote-build  --verbose  # Remote build with verbose output
#   just deploy router                              # Deploy to MikroTik router
deploy hostname *extra_opts="":
    @if [ "{{hostname}}" = "router" ]; then \
        log_info "Deploying to MikroTik router..."; \
        nix run .#router.apply; \
    else \
        log_info "Deploying to {{hostname}}..."; \
        deploy .#{{hostname}} --hostname {{hostname}} --skip-checks --remote-build {{extra_opts}}; \
    fi

# Migrate a local Calibre library to the server (one-time, after first deploy)
# Usage:
#   just calibre-import ~/Calibre\ Library                 # to server as alexander
#   just calibre-import /path/to/lib server alexander
calibre-import library_path hostname="server" username="alexander":
    @log_info "Importing Calibre library from '{{library_path}}' to {{username}}@{{hostname}}:/data/media/Books ..."
    @test -f "{{library_path}}/metadata.db" || { log_error "'{{library_path}}/metadata.db' not found — pass the Calibre library folder"; exit 1; }
    rsync -a --info=progress2 --rsync-path="sudo rsync" "{{library_path}}/" "{{username}}@{{hostname}}:/data/media/Books/"
    ssh {{username}}@{{hostname}} 'sudo chown -R calibre-web:media /data/media/Books'
    ssh {{username}}@{{hostname}} 'sudo systemctl restart calibre-web'
    @log_success "Import complete. Open http://calibre.lan and verify your library."


# Build configuration without switching (read-only artifact)
build:
    @log_info "Building configuration..."
    nixos-rebuild build --flake .

# Build and switch to a new generation locally (mutates system)
switch:
    @log_info "Switching to new generation locally..."
    sudo nixos-rebuild switch --flake .

# The installer ISO exists only for x86_64-linux, so it is named in full: a bare
# `.#installer-iso` resolves against the current system and misses on darwin.
iso_attr := ".#packages.x86_64-linux.installer-iso"

# Build the installer ISO (usage: just iso-build)
iso-build:
    @log_info "Building the installer ISO..."
    nix build "{{iso_attr}}" --out-link result
    @log_success "ISO available at ./result/iso/"

# Download the installer ISO CI last built, for machines that cannot build it (usage: just iso-fetch)
iso-fetch:
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/common.sh
    # Lands where iso-build would, so iso-write takes either. `result` is only a
    # GC-root link, and dropping it frees nothing until the next GC.
    [ -L result ] && rm result
    rm -rf result/iso
    if ! gh run download -n iso-installer -D result/iso; then
        log_error "No CI artifact iso-installer — cache.yml builds it on master; trigger one with 'gh workflow run cache.yml'"; exit 1
    fi
    log_success "ISO available at ./result/iso/"

# Write the built installer ISO to a USB device (usage: just iso-write /dev/sdX, or /dev/diskN on macOS)
iso-write device:
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/common.sh
    # The filename is asked of the flake, never guessed: `result` is a shared
    # out-link, so a glob can hand this recipe the wrong image to dd over a disk.
    if ! iso_name=$(nix eval --raw "{{iso_attr}}.name" 2>/dev/null); then
        log_error "Cannot evaluate {{iso_attr}}.name"; exit 1
    fi
    iso="result/iso/$iso_name"
    if [ ! -e "$iso" ]; then
        log_error "No ISO at $iso — run 'just iso-build' or 'just iso-fetch' first"; exit 1
    fi
    validate_write_disk {{device}} || exit 1
    log_warning "About to write $iso to {{device}} — this DESTROYS ALL DATA on it"
    # Typing the device back is the check: a timed window cancels on inattention
    # but not on naming the wrong disk, which is the mistake that actually hurts.
    if ! confirm {{device}} "Type '{{device}}' to confirm: "; then
        log_error "Aborted"; exit 1
    fi
    write_disk_image "$iso" {{device}}
    log_success "Written — boot {{device}}; console autologins as nixos (passwordless), SSH is key-based"

# Build the installer ISO and write it to a USB device (usage: just iso /dev/sdX)
iso device: iso-build (iso-write device)

# Update flake inputs (optionally a single input)
update *input:
    @log_info "Updating flake inputs..."
    nix flake update {{ input }}

# Check flake for issues
flake-check:
    @log_info "Checking flake configuration..."
    nix flake check

# Fetch GitHub repository hash for Nix packages
# Usage: just github-fetch-hash owner repo revision
# Example: just github-fetch-hash StephanJoubert home_assistant_solarman 1.5.1
github-fetch-hash owner repo revision:
    @log_info "Fetching hash for {{owner}}/{{repo}}@{{revision}}..."
    nix-shell -p nix-prefetch-github --run "nix-prefetch-github {{owner}} {{repo}} --rev {{revision}}"

# List available wallpapers in the wallpapers package registry
wallpaper-list:
    #!/usr/bin/env bash
    set -euo pipefail
    system=$(nix eval --impure --raw --expr 'builtins.currentSystem')
    echo "🖼️  Available wallpapers:"
    nix eval --json ".#packages.${system}.wallpapers.names" | jq -r '.[]' | sed 's/^/  /'

# Show system information
info:
    @echo "📋 System Information:"
    @echo "Current system: $(nix eval --impure --expr 'builtins.currentSystem')"
    @echo "Available systems:"
    @nix eval --json .#nixosConfigurations --apply builtins.attrNames | jq -r '.[]' | sed 's/^/  /'

# List available configurations (type: all | nixos | darwin)
configs-list type="all":
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/common.sh
    show() {
        case "$1" in
            nixos)  echo "🖥️  Available NixOS configurations:";  attr=nixosConfigurations ;;
            darwin) echo "🖥️  Available Darwin configurations:"; attr=darwinConfigurations ;;
        esac
        names=$(flake_output_names "$attr")
        if [ -z "$names" ]; then echo "  none"; else sed 's/^/  /' <<<"$names"; fi
    }
    case "{{ type }}" in
        all)          show nixos; show darwin ;;
        nixos|darwin) show "{{ type }}" ;;
        *) log_error "Unknown type: {{ type }} (use: all, nixos, darwin)"; exit 1 ;;
    esac

# Install packages temporarily for testing
shell packages:
    @log_info "Opening shell with packages: {{packages}}"
    nix shell {{packages}}

# Clean up old generations and garbage collect
cleanup:
    @log_info "Cleaning up old generations..."
    sudo nix-collect-garbage -d
    @log_info "Removing old boot entries..."
    sudo /run/current-system/bin/switch-to-configuration boot

# Format nix files with nixfmt-tree (writes)
format *path=".":
    @log_info "Formatting nix files with nixfmt-tree..."
    nix fmt {{path}}

# Check formatting without modifying files (read-only)
format-check:
    @log_info "Checking nix file formatting..."
    nix fmt -- --fail-on-change

# Lint with statix and deadnix (read-only)
lint:
    @log_info "Checking for issues with statix..."
    statix check .
    @log_info "Checking for dead code with deadnix..."
    deadnix --fail .
    @log_success "Lint passed"

# Auto-fix lint issues (statix fix + deadnix --edit)
lint-fix:
    @log_info "Auto-fixing statix issues..."
    statix fix .
    @log_info "Removing dead code..."
    deadnix --edit .
    @log_success "Lint fixes applied"

# Read-only quality umbrella: format-check + lint (CI-safe)
check: format-check lint
    @log_success "All quality checks passed"

# List secret names per secrets file. Key names are plaintext in a SOPS file,
# so nothing is decrypted.
secrets-list:
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/common.sh
    for file in secrets/*.yaml; do
        echo "$(basename "$file" .yaml):"
        yq 'del(.sops) | keys | .[]' "$file" | sed 's/^/  /'
    done

# Edit a secrets file, named by who can decrypt it (e.g. server)
secrets-edit audience:
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/common.sh
    file="secrets/{{audience}}.yaml"
    if [[ ! -f "$file" ]]; then
        log_error "No $file. Secrets files: $(basename -s .yaml secrets/*.yaml | tr '\n' ' ')"
        exit 1
    fi
    log_info "Editing $file..."
    sops "$file"

# Unlock GPG and restart the sops-nix user service to re-materialize secrets.
# Delegates to the `sops-fix` command generated by the home sops module
# (modules/home/security/sops), which resolves the launchd/systemd branch at
# build time. Run after a login/restart where the GPG passphrase was not cached.
secrets-fix:
    sops-fix

# Retire a host's secrets identity: its SOPS recipient (rekeying the files it
# could read) and its SSH host key in pass. Lists what it could decrypt.
# Usage:
#   just secrets-revoke host            # Preview (dry-run)
#   just secrets-revoke host --apply    # Revoke
secrets-revoke host mode="--dry-run":
    @./scripts/secrets-revoke.sh {{host}} {{mode}}

# Show flake outputs
outputs:
    @log_info "Flake outputs:"
    nix flake show

# Shellcheck every script under scripts/
scripts-validate:
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/common.sh
    log_info "Shellchecking scripts..."
    # Globbed rather than listed: a hand-maintained list silently stops covering
    # scripts as they are added, which is exactly when checking them matters.
    mapfile -t sources < <(find scripts -name '*.sh' | sort)
    # -x follows sourced files, so common.sh helpers resolve in each script.
    shellcheck -x "${sources[@]}"
    log_success "Shellcheck passed (${#sources[@]} scripts)"

# Show bootstrap script help
bootstrap-help:
    @echo "🚀 Bootstrap Script Help:"
    @echo ""
    @echo "Bootstrap Options:"
    @echo "  1. Complete bootstrap (recommended): just bootstrap <hostname> [username] [disk_password] [options...]"
    @echo "  2. Two-step process for advanced control:"
    @echo "     Step 1: just bootstrap-secrets <hostname> [disk_password]"
    @echo "     Step 2: set -x KEYSDIR <path_from_step1> && just bootstrap-deploy <hostname> [username] [options...]"
    @echo "  3. macOS host (run ON the Mac): just bootstrap-darwin <hostname>"
    @echo ""
    @echo "Usage:"
    @echo "  Complete: just bootstrap <hostname> [username] [disk_password] [extra_opts...]"
    @echo "  Step 1:   just bootstrap-secrets <hostname> [disk_password]"
    @echo "  Step 2:   just bootstrap-deploy <hostname> [username] [keysdir] [extra_opts...]"
    @echo ""
    @echo "Parameters:"
    @echo "  hostname                - Target hostname or IP address (required)"
    @echo "  username                - Target user for SSH connection (optional, defaults to current user)"
    @echo "  keysdir                 - Keys directory from step 1 (optional, uses KEYSDIR env var if not provided)"
    @echo "  disk_password           - Disk encryption password (optional, only for step 1)"
    @echo "  extra_opts              - Additional options to pass to nixos-anywhere (step 2)"
    @echo ""
    @echo "Environment variables:"
    @echo "  AUTO_APPROVE            - Skip interactive SOPS update confirmation (step 1)"
    @echo "  KEYSDIR                 - Keys directory set by bootstrap-secrets (step 1)"
    @echo ""
    @echo "Prerequisites:"
    @echo "  • SSH access to target host with passwordless sudo"
    @echo "  • 'pass' configured with file storage support"
    @echo "  • Target host configuration exists in flake"
    @echo ""
    @echo "Basic examples:"
    @echo "  just bootstrap myserver                                    # Complete bootstrap with current user"
    @echo "  just bootstrap myserver alexander                          # Complete bootstrap with specific user"
    @echo "  just bootstrap myserver alexander MyPassword123            # Complete bootstrap with disk encryption"
    @echo "  set -x KEYSDIR /tmp/keysXXX && just bootstrap myserver     # Use existing keys directory"
    @echo ""
    @echo "Two-step examples:"
    @echo "  just bootstrap-secrets myserver                            # Step 1: Prepare secrets"
    @echo "  set -x KEYSDIR /tmp/keysXXX                                # Export the path from step 1"
    @echo "  just bootstrap-deploy myserver alexander                   # Step 2: Deploy using KEYSDIR"
    @echo ""
    @echo "Examples with nixos-anywhere options:"
    @echo "  just bootstrap myserver alexander --build-on-remote        # Complete bootstrap with options"
    @echo "  just bootstrap myserver alexander --phases disko           # Complete bootstrap, disko phase only"
    @echo "  set -x KEYSDIR /tmp/keysXXX                                # For two-step process"
    @echo "  just bootstrap-deploy myserver alexander --build-on-remote # Two-step: deploy with options"
    @echo ""
    @echo "Complete bootstrap recipes:"
    @echo "  just bootstrap myserver                                    # Complete process with current user"
    @echo "  just bootstrap myserver alexander                          # Complete process with specific user"
    @echo "  just bootstrap myserver alexander mypassword               # Complete process with disk encryption"
    @echo "  set -x KEYSDIR /tmp/keysXXX && just bootstrap myserver     # Use existing keys, skip secrets generation"
    @echo "  just bootstrap myserver alexander mypassword --build-on-remote # Complete with options"
    @echo ""
    @echo "Common nixos-anywhere options:"
    @echo "  --build-on-remote       - Build the system on the target host"
    @echo "  --phases <phases>       - Run specific phases (kexec,disko,install,reboot)"
    @echo "  --debug                 - Enable debug output"
    @echo "  --no-reboot             - Don't reboot after installation"
    @echo "  --copy-host-keys        - Copy existing SSH host keys"
    @echo ""
    @echo "The bootstrap process will:"
    @echo "  1. Check prerequisites and SSH connectivity"
    @echo "  2. Setup SSH host keys (generate or retrieve from pass)"
    @echo "  3. Generate age keys for SOPS encryption"
    @echo "  4. Run nixos-anywhere with specified options to deploy NixOS"
    @echo "  5. Configure LUKS encryption if password provided (disko phase only)"
    @echo ""
    @echo "Manual two-step process:"
    @echo "  ./scripts/bootstrap/bootstrap-secrets.sh myserver                              # Returns KEYSDIR=/tmp/keysXXX"
    @echo "  ./scripts/bootstrap/bootstrap-secrets.sh myserver --disk-password mypassword   # With disk password"
    @echo "  ./scripts/bootstrap/bootstrap-deploy.sh alexander myserver /tmp/keysXXX        # Deploy using prepared keys"
    @echo "  ./scripts/bootstrap/bootstrap-deploy.sh alexander myserver /tmp/keysXXX --build-on-remote  # With extra options"
    @echo ""
    @echo "Scripts structure:"
    @echo "  scripts/common.sh                          - Shared utilities and logging functions"
    @echo "  scripts/bootstrap/bootstrap-secrets.sh     - SSH keys and secrets preparation (supports --disk-password)"
    @echo "  scripts/bootstrap/bootstrap-deploy.sh      - NixOS deployment with nixos-anywhere"


# Show all hosts that can be bootstrapped
bootstrap-targets:
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/common.sh
    echo "🎯 Available bootstrap targets:"
    all=$(flake_output_names nixosConfigurations)
    targets=$(grep -vx installer <<<"$all" || true)
    if [ -z "$targets" ]; then echo "  none"; else sed 's/^/  /' <<<"$targets"; fi

# ============================================
# Router Management (MikroTik via OpenTofu)
# ============================================

# Show generated terraform JSON for router
router-show:
    nix run .#router

# Checks syntax and provider schema only (no device, no import resolution)
router-validate:
    nix run .#router.validate

# Plan router configuration changes (dry-run)
router-plan:
    nix run .#router.plan

# Apply router configuration changes
router-apply:
    nix run .#router.apply

# Destroy router terraform state (dangerous!)
router-destroy:
    nix run .#router.destroy

# Create SSH backup of router
router-backup *opts="":
    nix run .#router.backup -- {{opts}}

# Edit router SOPS secrets
router-secrets-edit:
    sops infra/router/secrets.yaml

# Show router management help
router-help:
    @echo "Router Management Commands (OpenTofu-based):"
    @echo ""
    @echo "  just router-show             Show generated terraform JSON"
    @echo "  just router-validate         Check syntax and provider schema (offline, no import resolution)"
    @echo "  just router-plan             Plan changes (dry-run)"
    @echo "  just router-apply            Apply changes to router"
    @echo "  just router-backup           Create SSH backup of router"
    @echo "  just router-secrets-edit     Edit router SOPS secrets"
    @echo "  just router-destroy          Destroy terraform state (dangerous!)"
    @echo ""
    @echo "Prerequisites:"
    @echo "  - Old API enabled on router (/ip service set api disabled=no address=10.0.0.0/24)"
    @echo "  - SOPS secrets in infra/router/secrets.yaml:"
    @echo "    router-api-password, wifi-password, state-passphrase"
    @echo ""
    @echo "State Management:"
    @echo "  - State is natively encrypted by OpenTofu (PBKDF2 + AES-GCM) at infra/router/terraform.tfstate"
    @echo "  - Commit the updated state file after apply: git add infra/router/terraform.tfstate && git commit"
    @echo ""
    @echo "Workflow:"
    @echo "  1. Run 'just router-plan' to preview changes"
    @echo "  2. Run 'just router-apply' to apply changes"
    @echo "  3. Commit updated state: git add infra/router/terraform.tfstate && git commit"

# ============================================
# Tailnet Management (Tailscale ACL via OpenTofu)
# ============================================

# Show generated terraform JSON for the tailnet
tailnet-show:
    nix run .#tailnet

# Checks syntax and provider schema only (no device, no import resolution)
tailnet-validate:
    nix run .#tailnet.validate

# Plan tailnet policy changes (dry-run)
tailnet-plan:
    nix run .#tailnet.plan

# Apply tailnet policy changes
tailnet-apply:
    nix run .#tailnet.apply

# Edit tailnet SOPS secrets (state passphrase)
tailnet-secrets-edit:
    sops infra/tailnet/secrets.yaml

# Delete a host's devices from the tailnet
# Usage:
#   just tailnet-revoke host            # Preview (dry-run)
#   just tailnet-revoke host --apply    # Delete
tailnet-revoke host mode="--dry-run":
    @./scripts/tailnet-revoke.sh {{host}} {{mode}}

# ============================================
# DNS Management (sidorenko.me zone via OpenTofu)
# ============================================

# Show generated terraform JSON for the zone
dns-show:
    nix run .#dns

# Checks syntax and provider schema only (no device, no import resolution)
dns-validate:
    nix run .#dns.validate

# Plan zone changes (dry-run)
dns-plan:
    nix run .#dns.plan

# Apply zone changes
dns-apply:
    nix run .#dns.apply

# Edit DNS SOPS secrets (state passphrase)
dns-secrets-edit:
    sops infra/dns/secrets.yaml

# ============================================
# Object storage (R2 buckets via OpenTofu)
# ============================================

# Show generated terraform JSON for the R2 buckets
storage-show:
    nix run .#storage

# Checks syntax and provider schema only
storage-validate:
    nix run .#storage.validate

# Plan storage changes (dry-run)
storage-plan:
    nix run .#storage.plan

# Apply storage changes
storage-apply:
    nix run .#storage.apply

# Edit storage SOPS secrets (state passphrase)
storage-secrets-edit:
    sops infra/storage/secrets.yaml

# Edit provider credentials shared by every infra stack (Cloudflare token, Tailscale OAuth client)
infra-secrets-edit:
    sops infra/secrets.yaml

# Not part of `check`: needs network for `tofu init` and an age key for SOPS.
# Validate dormant infra configs against provider schemas.
infra-check: router-validate tailnet-validate dns-validate storage-validate
