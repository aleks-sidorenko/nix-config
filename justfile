# justfile for nix-config management
# Run `just --list` to see all available recipes

# Default recipe - show help
default:
    @just --list


# Prepare secrets and SSH keys only (Step 1 of bootstrap process)
bootstrap-secrets hostname disk_password="":
    @echo "🔐 Preparing secrets and SSH keys for {{hostname}}..."
    @if [ -n "{{disk_password}}" ]; then \
        KEYSDIR=$(./scripts/bootstrap/bootstrap-secrets.sh "{{hostname}}" --disk-password "{{disk_password}}"); \
    else \
        KEYSDIR=$(./scripts/bootstrap/bootstrap-secrets.sh "{{hostname}}"); \
    fi; \
    echo "✅ Keys directory: $KEYSDIR"; \
    echo "💡 To use in next command: set -x KEYSDIR $KEYSDIR"

# Deploy using existing keys directory (Step 2 of bootstrap process)
bootstrap-deploy hostname username="$USER" keysdir="${KEYSDIR:-}" *extra_opts="":
    @echo "🚀 Deploying NixOS to {{username}}@{{hostname}} using keys from {{keysdir}}..."
    @if [ -z "{{keysdir}}" ]; then \
        echo "❌ No keysdir provided and KEYSDIR environment variable not set"; \
        echo "💡 Run 'just bootstrap-secrets <hostname>' first, or provide keysdir explicitly"; \
        exit 1; \
    fi
    ./scripts/bootstrap/bootstrap-deploy.sh "{{username}}" "{{hostname}}" "{{keysdir}}" {{extra_opts}}

# Complete bootstrap process (secrets + deploy in one command)
bootstrap hostname username="$USER" disk_password="" *extra_opts="":
    @echo "🚀 Starting complete bootstrap process for {{username}}@{{hostname}}..."
    @if [ -n "$KEYSDIR" ]; then \
        echo "📁 Using existing KEYSDIR: $KEYSDIR"; \
    elif [ -n "{{disk_password}}" ]; then \
        echo "🔐 Generating secrets with disk password..."; \
        KEYSDIR=$(./scripts/bootstrap/bootstrap-secrets.sh "{{hostname}}" --disk-password "{{disk_password}}"); \
    else \
        echo "🔐 Generating secrets..."; \
        KEYSDIR=$(./scripts/bootstrap/bootstrap-secrets.sh "{{hostname}}"); \
    fi; \
    echo "✅ Keys directory: $KEYSDIR"; \
    echo "🚀 Proceeding with deployment..."; \
    ./scripts/bootstrap/bootstrap-deploy.sh "{{username}}" "{{hostname}}" "$KEYSDIR" {{extra_opts}}

# Bootstrap a fresh macOS (nix-darwin) host — run ON the target Mac
# Usage: just bootstrap-darwin <hostname>   (e.g. just bootstrap-darwin workbook)
bootstrap-darwin hostname:
    @echo "🍎 Bootstrapping macOS host {{hostname}}..."
    ./scripts/bootstrap/bootstrap-darwin.sh "{{hostname}}"

# Bootstrap Raspberry Pi firmware via SSH
bootstrap-rpi-firmware hostname username="$USER" target_dir="/mnt/boot" version="v1.42":
    @echo "🥧 Bootstrapping Raspberry Pi firmware on {{username}}@{{hostname}}..."
    @echo "📡 Target directory: {{target_dir}}"
    @echo "📦 Firmware version: {{version}}"
    @echo "🔗 Connecting via SSH and executing firmware installation script..."
    cat scripts/common.sh scripts/bootstrap/bootstrap-rpi-firmware.sh | ssh {{username}}@{{hostname}} 'bash -s -- {{target_dir}} {{version}}'
    @echo "✅ Raspberry Pi firmware bootstrap completed!"

# Format disks with disko configuration
# Usage:
#   just bootstrap-disk hostname                  # Preview changes (dry-run)
#   just bootstrap-disk hostname --apply          # Apply and format disks
bootstrap-disk hostname mode="--dry-run":
    @echo "💾 Formatting disks for {{hostname}} using disko..."
    @if [ "{{mode}}" = "--dry-run" ]; then \
        echo "🔍 Running in dry-run mode (preview only)..."; \
        echo "⚠️  No changes will be made to disks"; \
        sudo nix run github:nix-community/disko -- --mode disko --flake .#{{hostname}} --dry-run; \
    elif [ "{{mode}}" = "--apply" ]; then \
        echo "⚠️  WARNING: This will DESTROY ALL DATA on configured disks!"; \
        echo "⚠️  Press Ctrl+C within 5 seconds to cancel..."; \
        sleep 5; \
        sudo nix run github:nix-community/disko -- --mode disko --flake .#{{hostname}}; \
        echo "✅ Disks formatted successfully!"; \
        echo "💡 Run 'just deploy {{hostname}}' to apply mount configuration"; \
    else \
        echo "❌ Invalid mode: {{mode}}"; \
        echo "💡 Use '--dry-run' to preview or '--apply' to format"; \
        exit 1; \
    fi

# Deploy to a specific host using deploy-rs (or router-import for router)
# Usage:
#   just deploy hostname                            # Deploy with local build
#   just deploy hostname --remote-build             # Deploy with remote build
#   just deploy hostname --dry-run                  # Local build with dry-run
#   just deploy hostname --remote-build  --verbose  # Remote build with verbose output
#   just deploy router                              # Deploy to MikroTik router
deploy hostname *extra_opts="":
    @if [ "{{hostname}}" = "router" ]; then \
        echo "🌐 Deploying to MikroTik router..."; \
        nix run .#router.apply; \
    else \
        echo "🚢 Deploying to {{hostname}}..."; \
        deploy .#{{hostname}} --hostname {{hostname}} --skip-checks --remote-build {{extra_opts}}; \
    fi

# Migrate a local Calibre library to the server (one-time, after first deploy)
# Usage:
#   just calibre-import ~/Calibre\ Library                 # to server as alexander
#   just calibre-import /path/to/lib server alexander
calibre-import library_path hostname="server" username="alexander":
    @echo "📚 Importing Calibre library from '{{library_path}}' to {{username}}@{{hostname}}:/data/media/Books ..."
    @test -f "{{library_path}}/metadata.db" || { echo "❌ '{{library_path}}/metadata.db' not found — pass the Calibre library folder"; exit 1; }
    rsync -a --info=progress2 --rsync-path="sudo rsync" "{{library_path}}/" "{{username}}@{{hostname}}:/data/media/Books/"
    ssh {{username}}@{{hostname}} 'sudo chown -R calibre-web:media /data/media/Books'
    ssh {{username}}@{{hostname}} 'sudo systemctl restart calibre-web'
    @echo "✅ Import complete. Open http://calibre.local and verify your library."


# Build configuration without switching (read-only artifact)
build:
    @echo "🔨 Building configuration..."
    nixos-rebuild build --flake .

# Build and switch to a new generation locally (mutates system)
switch:
    @echo "🚀 Switching to new generation locally..."
    sudo nixos-rebuild switch --flake .

# Build the minimal NixOS installer ISO (output at ./result/iso/)
iso-build:
    @echo "💿 Building minimal installer ISO..."
    nix build .#install-isoConfigurations.minimal
    @echo "✅ ISO available at ./result/iso/ (nixos-minimal-*.iso)"

# Write the built installer ISO to a USB device (usage: just iso-write /dev/sdX)
iso-write device:
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/common.sh
    iso=$(ls result/iso/nixos-minimal-*.iso 2>/dev/null | head -1)
    if [ -z "$iso" ]; then
        log_error "No ISO found — run 'just iso-build' first"; exit 1
    fi
    validate_write_disk {{device}} || exit 1
    log_warning "About to write $iso to {{device}}"
    log_warning "This DESTROYS ALL DATA on {{device}}. Press Ctrl+C within 5s to cancel..."
    sleep 5
    sudo dd if="$iso" of={{device}} bs=4M status=progress conv=fsync
    log_success "Written — boot {{device}}; console autologins as nixos (passwordless), SSH is key-based"

# Build the installer ISO and write it to a USB device (usage: just iso /dev/sdX)
iso device: iso-build (iso-write device)

# Build a VM guest's disk images (usage: just image server-vm)
image host:
    #!/usr/bin/env bash
    set -euo pipefail
    source scripts/common.sh

    # Test the name, not the closure: evaluating toplevel here would turn any
    # assertion failure in an existing host into "No such host".
    if [ "$(nix eval --raw .#nixosConfigurations --apply 'c: if builtins.hasAttr "{{host}}" c then "yes" else "no"')" != "yes" ]; then
        log_error "No such host in this flake: {{host}}"
        exit 1
    fi

    # A `read` on a closed/non-interactive stdin hits EOF and, under -e, exits
    # 1 silently before the prompt's own decline message ever prints. Any
    # confirmation must check this first so a non-interactive caller (CI, a
    # script) fails loudly instead of looking like a clean no-op.
    confirm() {
        local word="$1" prompt="$2" reply
        if [ ! -t 0 ]; then
            log_error "Confirmation required (expected '$word') but stdin is not a terminal — run this interactively"
            exit 1
        fi
        read -rp "$prompt" reply
        [ "$reply" = "$word" ]
    }

    out="$HOME/.local/share/qemu/{{host}}"
    mkdir -p "$out"

    # RunAtLoad=true/KeepAlive=false leaves the launchd job registered even
    # after qemu fails to exec (e.g. no disk images yet), so "loaded" alone
    # cannot mean "in use". A job in `not running` or `spawn scheduled` holds
    # no open file handles — `launchctl kickstart -k` starts it directly, so
    # it's left alone entirely (a bootout here would only unregister it from
    # the domain until next login, turning the documented `kickstart -k` that
    # follows into a hard failure). Only `running` is a guest someone may be
    # using, and killing that costs unsaved guest state, so it needs explicit
    # consent; a state this doesn't recognize gets the same consent prompt,
    # since it can't prove the job holds no handles either — fail safe, not
    # open. A missing job (`launchctl print` exits 113) never enters this
    # block at all.
    agent="gui/$(id -u)/org.nixos.qemu-{{host}}"
    if agent_status=$(launchctl print "$agent" 2>/dev/null); then
        state=$(echo "$agent_status" | sed -n 's/^[[:space:]]*state = //p' | head -1)
        case "$state" in
        "not running" | "spawn scheduled")
            : # idle registration; nothing to clear, kickstart -k will start it
            ;;
        *)
            if [ "$state" = "running" ]; then
                log_warning "The guest is running — imaging now risks corrupting its disks"
            else
                log_warning "The guest's launchd job is in an unrecognized state ('$state') — treating it as potentially in use"
            fi
            if ! confirm bootout "Type 'bootout' to stop the guest and continue: "; then
                log_error "Aborted"; exit 1
            fi
            launchctl bootout "$agent" 2>/dev/null || true
            ;;
        esac
    fi

    install_image() {
        rm -f "$out/.$1.tmp"
        cp "result-vm/$2" "$out/.$1.tmp"
        chmod u+w "$out/.$1.tmp"
        mv -f "$out/.$1.tmp" "$out/$1"
    }

    # Firmware state is independent of the root-image decision below: seed it
    # up front so a decline there still leaves the guest with a consistent
    # varstore instead of none at all.
    if [ ! -e "$out/vars.img" ]; then
        # Limitation: the recipe is parameterised by guest, but the firmware
        # comes from the workbook's qemu unconditionally. Another VM host would
        # need this to follow the guest's actual hypervisor host.
        qemu=$(nix build --no-link --print-out-paths '.#darwinConfigurations.workbook.config.nix-config.services.virtualisation.qemu.package')
        rm -f "$out/.vars.img.tmp"
        cp "$qemu/share/qemu/edk2-arm-vars.fd" "$out/.vars.img.tmp"
        chmod u+w "$out/.vars.img.tmp"
        mv -f "$out/.vars.img.tmp" "$out/vars.img"
        log_success "vars.img seeded"
    fi

    # /persist lives in the root image, so replacing it destroys the guest's
    # host key and every service's state (the *arr databases, the Jellyfin
    # library, the Minecraft world). Only the data disk — /data, /backup and
    # /home — survives. Never implicit.
    if [ -e "$out/root.qcow2" ]; then
        log_warning "About to REPLACE $out/root.qcow2 — the guest's host key and all of /persist go with it"
        if ! confirm replace "Type 'replace' to continue: "; then
            log_error "Aborted"; exit 1
        fi
    fi

    log_info "Building {{host}} disk images (requires an aarch64-linux builder)..."
    nix build ".#nixosConfigurations.{{host}}.config.system.build.diskoImages" --out-link result-vm

    install_image root.qcow2 root.qcow2
    log_success "root.qcow2 written"

    # The data disk is the one thing that survives re-imaging: create-only.
    if [ -e "$out/data.qcow2" ]; then
        log_info "Keeping the existing $out/data.qcow2 — delete it by hand to start over"
    else
        install_image data.qcow2 data.qcow2
        log_success "data.qcow2 created"
    fi

    log_success "Images ready in $out"

# Update flake inputs (optionally a single input)
update *input:
    @echo "📦 Updating flake inputs..."
    nix flake update {{ input }}

# Check flake for issues
flake-check:
    @echo "🔍 Checking flake configuration..."
    nix flake check

# Fetch GitHub repository hash for Nix packages
# Usage: just github-fetch-hash owner repo revision
# Example: just github-fetch-hash StephanJoubert home_assistant_solarman 1.5.1
github-fetch-hash owner repo revision:
    @echo "🔐 Fetching hash for {{owner}}/{{repo}}@{{revision}}..."
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

# List available configurations (type: all | nixos | darwin | home)
list-configs type="all":
    #!/usr/bin/env bash
    set -euo pipefail
    show() {
        case "$1" in
            nixos)  echo "🖥️  Available NixOS configurations:";       attr=nixosConfigurations ;;
            darwin) echo "🖥️  Available Darwin configurations:";      attr=darwinConfigurations ;;
            home)   echo "🏠 Available home-manager configurations:"; attr=homeConfigurations ;;
        esac
        nix eval --json ".#${attr}" --apply builtins.attrNames | jq -r '.[]' | sed 's/^/  /'
    }
    case "{{ type }}" in
        all)               show nixos; show darwin; show home ;;
        nixos|darwin|home) show "{{ type }}" ;;
        *) echo "Unknown type: {{ type }} (use: all, nixos, darwin, home)" >&2; exit 1 ;;
    esac

# Install packages temporarily for testing
shell packages:
    @echo "🐚 Opening shell with packages: {{packages}}"
    nix shell {{packages}}

# Clean up old generations and garbage collect
cleanup:
    @echo "🧹 Cleaning up old generations..."
    sudo nix-collect-garbage -d
    @echo "🗑️  Removing old boot entries..."
    sudo /run/current-system/bin/switch-to-configuration boot

# Format nix files with nixfmt-tree (writes)
format *path=".":
    @echo "✨ Formatting nix files with nixfmt-tree..."
    nix fmt {{path}}

# Check formatting without modifying files (read-only)
format-check:
    @echo "🔍 Checking nix file formatting..."
    nix fmt -- --fail-on-change

# Lint with statix and deadnix (read-only)
lint:
    @echo "🕵️  Checking for issues with statix..."
    statix check .
    @echo "💀 Checking for dead code with deadnix..."
    deadnix --fail .
    @echo "✅ Lint passed!"

# Auto-fix lint issues (statix fix + deadnix --edit)
lint-fix:
    @echo "🔧 Auto-fixing statix issues..."
    statix fix .
    @echo "💀 Removing dead code..."
    deadnix --edit .
    @echo "✅ Lint fixes applied!"

# Read-only quality umbrella: format-check + lint (CI-safe)
check: format-check lint
    @echo "✅ All quality checks passed!"

# Show secrets managed by SOPS
secrets-list:
    @echo "🔐 SOPS secrets:"
    @echo "NixOS secrets:"
    @sops --decrypt modules/nixos/secrets.yaml | yq '.data | keys' | sed 's/^/  /'
    @echo "Home-manager secrets:"
    @sops --decrypt modules/home/secrets.yaml | yq '.data | keys' | sed 's/^/  /' 2>/dev/null || echo "  No home secrets found"

# Edit SOPS secrets
secrets-edit type:
    @echo "🔓 Editing {{type}} secrets..."
    sops modules/{{type}}/secrets.yaml

# Unlock GPG and restart the sops-nix user service to re-materialize secrets.
# Delegates to the `sops-fix` command generated by the home sops module
# (modules/home/security/sops), which resolves the launchd/systemd branch at
# build time. Run after a login/restart where the GPG passphrase was not cached.
secrets-fix:
    sops-fix

# Show flake outputs
outputs:
    @echo "📤 Flake outputs:"
    nix flake show

# Show disk usage by store paths
disk-usage:
    @echo "💾 Nix store disk usage:"
    du -sh /nix/store | head -20

# Validate bootstrap scripts
bootstrap-validate:
    @echo "🔍 Validating bootstrap scripts..."
    shellcheck scripts/common.sh
    shellcheck scripts/bootstrap/bootstrap-secrets.sh
    shellcheck scripts/bootstrap/bootstrap-deploy.sh
    shellcheck scripts/bootstrap/bootstrap-rpi-firmware.sh
    shellcheck scripts/bootstrap/bootstrap-darwin.sh
    @echo "✅ Bootstrap scripts validation passed"

# Show bootstrap script help
bootstrap-help:
    @echo "🚀 Bootstrap Script Help:"
    @echo ""
    @echo "Bootstrap Options:"
    @echo "  1. Complete bootstrap (recommended): just bootstrap <hostname> [username] [disk_password] [options...]"
    @echo "  2. Two-step process for advanced control:"
    @echo "     Step 1: just bootstrap-secrets <hostname> [disk_password]"
    @echo "     Step 2: set -x KEYSDIR <path_from_step1> && just bootstrap-deploy <hostname> [username] [options...]"
    @echo "  3. Raspberry Pi firmware only: just bootstrap-rpi-firmware <hostname> [username] [target_dir] [version]"
    @echo "  4. macOS host (run ON the Mac): just bootstrap-darwin <hostname>"
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
    @echo "Raspberry Pi firmware examples:"
    @echo "  just bootstrap-rpi-firmware myrpi                          # Install firmware with defaults"
    @echo "  just bootstrap-rpi-firmware myrpi pi /boot v1.50           # Custom user, target dir, and version"
    @echo "  just bootstrap-rpi-firmware 192.168.1.100 root             # Custom user, default dir and version"
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
    @echo "  scripts/bootstrap/bootstrap-rpi-firmware.sh - Raspberry Pi firmware installation"


# Show all hosts that can be bootstrapped
bootstrap-targets:
    @echo "🎯 Available bootstrap targets:"
    @echo "NixOS configurations that can be bootstrapped:"
    @nix eval --json .#nixosConfigurations --apply builtins.attrNames | jq -r '.[]' | grep -v "install-iso" | sed 's/^/  /'

# ============================================
# Router Management (MikroTik via OpenTofu)
# ============================================

# Show generated terraform JSON for router
router-show:
    nix run .#router

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
router-secrets:
    sops infra/router/secrets.yaml

# Show router management help
router-help:
    @echo "Router Management Commands (OpenTofu-based):"
    @echo ""
    @echo "  just router-show             Show generated terraform JSON"
    @echo "  just router-plan             Plan changes (dry-run)"
    @echo "  just router-apply            Apply changes to router"
    @echo "  just router-backup           Create SSH backup of router"
    @echo "  just router-secrets          Edit router SOPS secrets"
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
