# justfile for nix-config management
# Run `just --list` to see all available recipes

# Default recipe - show help
default:
    @just --list


# Prepare secrets and SSH keys only (Step 1 of bootstrap process)
bootstrap-secrets hostname disk_password="":
    @echo "🔐 Preparing secrets and SSH keys for {{hostname}}..."
    @if [ -n "{{disk_password}}" ]; then \
        KEYSDIR=$(./scripts/secrets.sh "{{hostname}}" --disk-password "{{disk_password}}" | tail -1); \
    else \
        KEYSDIR=$(./scripts/secrets.sh "{{hostname}}" | tail -1); \
    fi; \
    echo "✅ Keys directory: $KEYSDIR"; \
    echo "💡 To use in next command: export KEYSDIR=$KEYSDIR"

# Deploy using existing keys directory (Step 2 of bootstrap process)  
bootstrap-deploy hostname username="$USER" keysdir="${KEYSDIR:-}" *extra_opts="":
    @echo "🚀 Deploying NixOS to {{username}}@{{hostname}} using keys from {{keysdir}}..."
    @if [ -z "{{keysdir}}" ]; then \
        echo "❌ No keysdir provided and KEYSDIR environment variable not set"; \
        echo "💡 Run 'just bootstrap-secrets <hostname>' first, or provide keysdir explicitly"; \
        exit 1; \
    fi
    ./scripts/deploy.sh "{{username}}" "{{hostname}}" "{{keysdir}}" {{extra_opts}}

# Complete bootstrap process (secrets + deploy in one command)
bootstrap hostname username="$USER" disk_password="" *extra_opts="":
    @echo "🚀 Starting complete bootstrap process for {{username}}@{{hostname}}..."
    @if [ -n "$KEYSDIR" ]; then \
        echo "📁 Using existing KEYSDIR: $KEYSDIR"; \
    elif [ -n "{{disk_password}}" ]; then \
        echo "🔐 Generating secrets with disk password..."; \
        KEYSDIR=$(./scripts/secrets.sh "{{hostname}}" --disk-password "{{disk_password}}" | tail -1); \
    else \
        echo "🔐 Generating secrets..."; \
        KEYSDIR=$(./scripts/secrets.sh "{{hostname}}" | tail -1); \
    fi; \
    echo "✅ Keys directory: $KEYSDIR"; \
    echo "🚀 Proceeding with deployment..."; \
    ./scripts/deploy.sh "{{username}}" "{{hostname}}" "$KEYSDIR" {{extra_opts}}

# Bootstrap Raspberry Pi firmware via SSH
bootstrap-rpi-firmware hostname username="$USER" target_dir="/mnt/boot" version="v1.42":
    @echo "🥧 Bootstrapping Raspberry Pi firmware on {{username}}@{{hostname}}..."
    @echo "📡 Target directory: {{target_dir}}"
    @echo "📦 Firmware version: {{version}}"
    @echo "🔗 Connecting via SSH and executing firmware installation script..."
    ssh {{username}}@{{hostname}} 'bash -s -- {{target_dir}} {{version}}' < scripts/rpi/firmware.sh
    @echo "✅ Raspberry Pi firmware bootstrap completed!"

# Deploy to a specific host using deploy-rs
# Usage:
#   just deploy hostname                            # Deploy with local build
#   just deploy hostname --remote-build             # Deploy with remote build
#   just deploy hostname --dry-run                  # Local build with dry-run
#   just deploy hostname --remote-build  --verbose  # Remote build with verbose output
deploy hostname *extra_opts="":
    @echo "🚢 Deploying to {{hostname}}..."    
    deploy .#{{hostname}} --hostname {{hostname}} --skip-checks {{extra_opts}}; \
    

# Build and switch to a new generation locally (for testing)
build-local:
    @echo "🔨 Building local configuration..."
    sudo nixos-rebuild switch --flake .

# Build without switching (dry-run)
build-test:
    @echo "🧪 Testing build configuration..."
    nixos-rebuild build --flake .

# Update flake inputs
update:
    @echo "📦 Updating flake inputs..."
    nix flake update

# Check flake for issues
check:
    @echo "🔍 Checking flake configuration..."
    nix flake check

# Show system information
info:
    @echo "📋 System Information:"
    @echo "Current system: $(nix eval --impure --expr 'builtins.currentSystem')"
    @echo "Available systems:"
    @nix eval --json .#nixosConfigurations --apply builtins.attrNames | jq -r '.[]' | sed 's/^/  /'

# List available NixOS configurations
list-configs:
    @echo "🖥️  Available NixOS configurations:"
    @nix eval --json .#nixosConfigurations --apply builtins.attrNames | jq -r '.[]' | sed 's/^/  /'

# List available home-manager configurations  
list-homes:
    @echo "🏠 Available home-manager configurations:"
    @nix eval --json .#homeConfigurations --apply builtins.attrNames | jq -r '.[]' | sed 's/^/  /'

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

# Format nix files with nixfmt-rfc-style (default formatter)
format:
    @echo "✨ Formatting nix files with nixfmt-rfc-style..."
    find . -name "*.nix" -not -path "./result*" -not -path "./.direnv/*" | xargs nixfmt

# Format nix files with alejandra
format-alejandra:
    @echo "✨ Formatting nix files with alejandra..."
    find . -name "*.nix" -not -path "./result*" -not -path "./.direnv/*" | xargs alejandra

# Format nix files with nixpkgs-fmt
format-nixpkgs:
    @echo "✨ Formatting nix files with nixpkgs-fmt..."
    find . -name "*.nix" -not -path "./result*" -not -path "./.direnv/*" | xargs nixpkgs-fmt

# Check nix file formatting without making changes
format-check:
    @echo "🔍 Checking nix file formatting..."
    @if find . -name "*.nix" -not -path "./result*" -not -path "./.direnv/*" | xargs nixfmt --check; then \
        echo "✅ All nix files are properly formatted"; \
    else \
        echo "❌ Some nix files need formatting. Run 'just format' to fix them."; \
        exit 1; \
    fi

# Format specific file or directory
format-path path:
    @echo "✨ Formatting {{path}}..."
    @if [ -f "{{path}}" ]; then \
        nixfmt "{{path}}"; \
    elif [ -d "{{path}}" ]; then \
        find "{{path}}" -name "*.nix" | xargs nixfmt; \
    else \
        echo "❌ Path {{path}} not found"; \
        exit 1; \
    fi

# Run all code quality checks (format, lint, dead code detection)
lint:
    @echo "🔍 Running comprehensive code quality checks..."
    @echo "📝 Formatting nix files..."
    just format
    @echo "🕵️  Checking for issues with statix..."
    statix check .
    @echo "💀 Checking for dead code with deadnix..."
    deadnix --fail .
    @echo "✅ All quality checks passed!"

# Fix common nix issues automatically
lint-fix:
    @echo "🔧 Auto-fixing nix issues..."
    @echo "📝 Formatting nix files..."
    just format
    @echo "🔧 Auto-fixing statix issues..."
    statix fix .
    @echo "💀 Removing dead code..."
    deadnix --edit .
    @echo "✅ Auto-fixes completed!"

# Check code quality without making changes
lint-check:
    @echo "🔍 Checking code quality (no changes)..."
    just format-check
    @echo "🕵️  Checking for issues with statix..."
    statix check .
    @echo "💀 Checking for dead code with deadnix..."
    deadnix --fail .
    @echo "✅ Quality check passed!"

# Show secrets managed by SOPS
secrets:
    @echo "🔐 SOPS secrets:"
    @echo "NixOS secrets:"
    @sops --decrypt modules/nixos/secrets.yaml | yq '.data | keys' | sed 's/^/  /'
    @echo "Home-manager secrets:"  
    @sops --decrypt modules/home/secrets.yaml | yq '.data | keys' | sed 's/^/  /' 2>/dev/null || echo "  No home secrets found"

# Edit SOPS secrets
edit-secrets type:
    @echo "🔓 Editing {{type}} secrets..."
    sops modules/{{type}}/secrets.yaml

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
    shellcheck scripts/secrets.sh
    shellcheck scripts/deploy.sh
    shellcheck scripts/rpi/firmware.sh
    @echo "✅ Bootstrap scripts validation passed"

# Show bootstrap script help
bootstrap-help:
    @echo "🚀 Bootstrap Script Help:"
    @echo ""
    @echo "Bootstrap Options:"
    @echo "  1. Complete bootstrap (recommended): just bootstrap <hostname> [username] [disk_password] [options...]"
    @echo "  2. Two-step process for advanced control:"
    @echo "     Step 1: just bootstrap-secrets <hostname> [disk_password]"
    @echo "     Step 2: export KEYSDIR=<path_from_step1> && just bootstrap-deploy <hostname> [username] [options...]"
    @echo "  3. Raspberry Pi firmware only: just bootstrap-rpi-firmware <hostname> [username] [target_dir] [version]"
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
    @echo "  export KEYSDIR=/tmp/keysXXX && just bootstrap myserver     # Use existing keys directory"
    @echo ""
    @echo "Raspberry Pi firmware examples:"
    @echo "  just bootstrap-rpi-firmware myrpi                          # Install firmware with defaults"
    @echo "  just bootstrap-rpi-firmware myrpi pi /boot v1.50           # Custom user, target dir, and version"
    @echo "  just bootstrap-rpi-firmware 192.168.1.100 root             # Custom user, default dir and version"
    @echo ""
    @echo "Two-step examples:"
    @echo "  just bootstrap-secrets myserver                            # Step 1: Prepare secrets"
    @echo "  export KEYSDIR=/tmp/keysXXX                                # Export the path from step 1"
    @echo "  just bootstrap-deploy myserver alexander                   # Step 2: Deploy using KEYSDIR"
    @echo ""
    @echo "Examples with nixos-anywhere options:"
    @echo "  just bootstrap myserver alexander --build-on-remote        # Complete bootstrap with options"
    @echo "  just bootstrap myserver alexander --phases disko           # Complete bootstrap, disko phase only"
    @echo "  export KEYSDIR=/tmp/keysXXX                                # For two-step process"
    @echo "  just bootstrap-deploy myserver alexander --build-on-remote # Two-step: deploy with options"
    @echo ""
    @echo "Complete bootstrap recipes:"
    @echo "  just bootstrap myserver                                    # Complete process with current user"
    @echo "  just bootstrap myserver alexander                          # Complete process with specific user"
    @echo "  just bootstrap myserver alexander mypassword               # Complete process with disk encryption"
    @echo "  export KEYSDIR=/tmp/keysXXX && just bootstrap myserver     # Use existing keys, skip secrets generation"
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
    @echo "  ./scripts/secrets.sh myserver                              # Returns KEYSDIR=/tmp/keysXXX"
    @echo "  ./scripts/secrets.sh myserver --disk-password mypassword   # With disk password"
    @echo "  ./scripts/deploy.sh alexander myserver /tmp/keysXXX        # Deploy using prepared keys"
    @echo "  ./scripts/deploy.sh alexander myserver /tmp/keysXXX --build-on-remote  # With extra options"
    @echo ""
    @echo "Scripts structure:"
    @echo "  scripts/common.sh       - Shared utilities and logging functions"
    @echo "  scripts/secrets.sh      - SSH keys and secrets preparation (supports --disk-password)"
    @echo "  scripts/deploy.sh       - NixOS deployment with nixos-anywhere"
    

# Show all hosts that can be bootstrapped
bootstrap-targets:
    @echo "🎯 Available bootstrap targets:"
    @echo "NixOS configurations that can be bootstrapped:"
    @nix eval --json .#nixosConfigurations --apply builtins.attrNames | jq -r '.[]' | grep -v "install-iso" | sed 's/^/  /'
