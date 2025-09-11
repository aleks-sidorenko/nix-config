# justfile for nix-config management
# Run `just --list` to see all available recipes

# Default recipe - show help
default:
    @just --list

# Bootstrap NixOS on a remote host with nixos-anywhere
bootstrap hostname username="$USER" disk_password="" *nixos_anywhere_opts="":
    @echo "🚀 Bootstrapping NixOS for {{username}}@{{hostname}}..."
    @echo "🔐 Step 1: Setting up secrets and SSH keys..."
    @keysdir_output=$(./scripts/secrets.sh "{{hostname}}" 2>&1 | tee /dev/stderr | tail -1); \
    keysdir=$$(echo "$$keysdir_output" | grep "^KEYSDIR=" | cut -d= -f2); \
    if [ -z "$$keysdir" ]; then \
        echo "❌ Failed to get keys directory from secrets.sh"; \
        exit 1; \
    fi; \
    echo "🚀 Step 2: Running nixos-anywhere..."; \
    if [ -n "{{disk_password}}" ]; then \
        echo "🔒 Using disk encryption"; \
        ./scripts/deploy.sh "$$keysdir" "{{username}}" "{{hostname}}" "{{disk_password}}" {{nixos_anywhere_opts}}; \
    else \
        echo "🔓 No disk encryption"; \
        ./scripts/deploy.sh "$$keysdir" "{{username}}" "{{hostname}}" {{nixos_anywhere_opts}}; \
    fi

# Bootstrap without disk encryption (explicit)
bootstrap-plain hostname username="$USER" *nixos_anywhere_opts="":
    @echo "🚀 Bootstrapping NixOS for {{username}}@{{hostname}} (no encryption)..."
    just bootstrap {{hostname}} {{username}} "" {{nixos_anywhere_opts}}

# Bootstrap with disk encryption (interactive password prompt)
bootstrap-encrypted hostname username="$USER" *nixos_anywhere_opts="":
    @echo "🚀 Bootstrapping NixOS for {{username}}@{{hostname}} (with encryption)..."
    @echo -n "Enter disk encryption password: "
    @read -s disk_password && \
    just bootstrap {{hostname}} {{username}} "$$disk_password" {{nixos_anywhere_opts}}

# Bootstrap with build on remote (faster for slow local machines)
bootstrap-remote hostname username="$USER" disk_password="":
    @echo "🚀 Bootstrapping NixOS for {{username}}@{{hostname}} (build on remote)..."
    just bootstrap {{hostname}} {{username}} "{{disk_password}}" --build-on-remote

# Bootstrap with only disko phase (partition and format disks only)
bootstrap-disko-only hostname username="$USER" disk_password="":
    @echo "🚀 Running disko phase only for {{username}}@{{hostname}}..."
    just bootstrap {{hostname}} {{username}} "{{disk_password}}" --phases disko

# Bootstrap with only install phase (install NixOS, assumes disks are already prepared)
bootstrap-install-only hostname username="$USER":
    @echo "🚀 Running install phase only for {{username}}@{{hostname}}..."
    just bootstrap {{hostname}} {{username}} "" --phases install

# Bootstrap with build on remote and disko only
bootstrap-remote-disko hostname username="$USER" disk_password="":
    @echo "🚀 Running disko phase only for {{username}}@{{hostname}} (build on remote)..."
    just bootstrap {{hostname}} {{username}} "{{disk_password}}" --build-on-remote --phases disko

# Bootstrap with build on remote and install only
bootstrap-remote-install hostname username="$USER":
    @echo "🚀 Running install phase only for {{username}}@{{hostname}} (build on remote)..."
    just bootstrap {{hostname}} {{username}} "" --build-on-remote --phases install

# Bootstrap with custom phases (e.g., just kexec,disko or disko,install)
bootstrap-phases hostname username="$USER" disk_password="" phases="disko,install":
    @echo "🚀 Bootstrapping NixOS for {{username}}@{{hostname}} with phases: {{phases}}..."
    @if echo "{{phases}}" | grep -q "disko"; then \
        echo "🔒 Disko phase detected - disk encryption password will be used if provided"; \
        just bootstrap {{hostname}} {{username}} "{{disk_password}}" --phases {{phases}}; \
    else \
        echo "ℹ️  No disko phase - disk encryption password not needed"; \
        just bootstrap {{hostname}} {{username}} "" --phases {{phases}}; \
    fi

# Prepare secrets and SSH keys only (Step 1 of bootstrap process)
bootstrap-secrets hostname force="":
    @echo "🔐 Preparing secrets and SSH keys for {{hostname}}..."
    @if [ "{{force}}" = "--force" ]; then \
        ./scripts/secrets.sh "{{hostname}}" --force; \
    else \
        ./scripts/secrets.sh "{{hostname}}"; \
    fi

# Run nixos-anywhere only with existing keys directory (Step 2 of bootstrap process)
bootstrap-deploy keysdir hostname username="$USER" disk_password="" *nixos_anywhere_opts="":
    @echo "🚀 Deploying NixOS for {{username}}@{{hostname}} with prepared keys..."
    @if [ -n "{{disk_password}}" ]; then \
        echo "🔒 Using disk encryption"; \
        ./scripts/deploy.sh "{{keysdir}}" "{{username}}" "{{hostname}}" "{{disk_password}}" {{nixos_anywhere_opts}}; \
    else \
        echo "🔓 No disk encryption"; \
        ./scripts/deploy.sh "{{keysdir}}" "{{username}}" "{{hostname}}" {{nixos_anywhere_opts}}; \
    fi

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

# Deploy to a specific host using nixos-rebuild
deploy hostname:
    @echo "🚢 Deploying to {{hostname}}..."
    nixos-rebuild switch --flake .#{{hostname}} --target-host {{hostname}} --use-remote-sudo

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
    @echo "✅ Bootstrap scripts validation passed"

# Show bootstrap script help
bootstrap-help:
    @echo "🚀 Bootstrap Script Help:"
    @echo ""
    @echo "Two-Step Bootstrap Process:"
    @echo "  The bootstrap process is now split into two steps for better control:"
    @echo "  1. Secrets preparation (secrets.sh) - Sets up SSH keys and age keys"
    @echo "  2. NixOS deployment (deploy.sh) - Runs nixos-anywhere"
    @echo ""
    @echo "Usage: just bootstrap <hostname> [username] [disk_password] [nixos_anywhere_options...]"
    @echo ""
    @echo "Parameters:"
    @echo "  hostname                - Target hostname or IP address (required)"
    @echo "  username                - Target user (optional, defaults to current user: $USER)"
    @echo "  disk_password           - Disk encryption password (optional, only used for disko phase)"
    @echo "  nixos_anywhere_options  - Additional options to pass to nixos-anywhere"
    @echo ""
    @echo "Environment variables:"
    @echo "  NIXOS_ANYWHERE_OPTS     - Additional options to pass to nixos-anywhere"
    @echo "  AUTO_APPROVE            - Skip interactive SOPS update confirmation"
    @echo ""
    @echo "Prerequisites:"
    @echo "  • SSH access to target host with passwordless sudo"
    @echo "  • 'pass' configured with file storage support"
    @echo "  • Target host configuration exists in flake"
    @echo ""
    @echo "Basic examples:"
    @echo "  just bootstrap myserver                                    # No encryption, current user"
    @echo "  just bootstrap myserver alexander                          # No encryption, specified user"
    @echo "  just bootstrap myserver alexander MyPassword123            # With LUKS encryption"
    @echo ""
    @echo "Examples with nixos-anywhere options:"
    @echo "  just bootstrap myserver alexander '' --build-on-remote    # Build on target host"
    @echo "  just bootstrap myserver alexander '' --phases disko       # Only partition disks"
    @echo "  just bootstrap myserver alexander '' --build-on-remote --phases disko"
    @echo "  NIXOS_ANYWHERE_OPTS='--debug' just bootstrap myserver     # Using environment variable"
    @echo ""
    @echo "Convenient recipes:"
    @echo "  just bootstrap-plain myserver                              # Explicit no encryption"
    @echo "  just bootstrap-encrypted myserver                          # Interactive password prompt"
    @echo "  just bootstrap-remote myserver                             # Build on remote host"
    @echo "  just bootstrap-disko-only myserver                         # Only run disko phase"
    @echo "  just bootstrap-install-only myserver                       # Only run install phase (no encryption needed)"
    @echo "  just bootstrap-remote-disko myserver                       # Remote build + disko only"
    @echo "  just bootstrap-remote-install myserver                     # Remote build + install only"
    @echo "  just bootstrap-phases myserver '' '' 'kexec,disko'         # Custom phases (password auto-detected)"
    @echo ""
    @echo "Two-step process recipes:"
    @echo "  just bootstrap-secrets myserver                            # Step 1: Prepare secrets only"
    @echo "  just bootstrap-secrets myserver --force                    # Force regenerate keys"
    @echo "  just bootstrap-deploy /tmp/keysXXX alexander myserver      # Step 2: Deploy with existing keys"
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
    @echo "  ./scripts/deploy.sh /tmp/keysXXX alexander myserver      # Deploy using prepared keys"
    @echo ""
    @echo "Scripts structure:"
    @echo "  scripts/common.sh       - Shared utilities and logging functions"
    @echo "  scripts/secrets.sh      - SSH keys and secrets preparation"
    @echo "  scripts/deploy.sh    - NixOS deployment with nixos-anywhere"

# Show all hosts that can be bootstrapped
bootstrap-targets:
    @echo "🎯 Available bootstrap targets:"
    @echo "NixOS configurations that can be bootstrapped:"
    @nix eval --json .#nixosConfigurations --apply builtins.attrNames | jq -r '.[]' | grep -v "install-iso" | sed 's/^/  /'
