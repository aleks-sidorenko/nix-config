# justfile for nix-config management
# Run `just --list` to see all available recipes

# Default recipe - show help
default:
    @just --list

# Bootstrap NixOS on a remote host with nixos-anywhere
bootstrap hostname username="$USER":
    @echo "🚀 Bootstrapping NixOS for {{username}}@{{hostname}}..."
    ./scripts/bootstrap.sh "{{username}}" "{{hostname}}"

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

# Validate bootstrap script
bootstrap-validate:
    @echo "🔍 Validating bootstrap script..."
    shellcheck scripts/bootstrap.sh
    @echo "✅ Bootstrap script validation passed"

# Show bootstrap script help
bootstrap-help:
    @echo "🚀 Bootstrap Script Help:"
    @echo ""
    @echo "Usage: just bootstrap <hostname> [username]"
    @echo ""
    @echo "Parameters:"
    @echo "  hostname - Target hostname or IP address (required)"
    @echo "  username - Target user (optional, defaults to current user: $USER)"
    @echo ""
    @echo "Prerequisites:"
    @echo "  • SSH access to target host with passwordless sudo"
    @echo "  • 'pass' configured with file storage support"
    @echo "  • Target host configuration exists in flake"
    @echo ""
    @echo "Examples:"
    @echo "  just bootstrap myserver              # Uses current user ($USER)"
    @echo "  just bootstrap myserver alexander    # Uses specified user"
    @echo ""
    @echo "The script will:"
    @echo "  1. Check prerequisites and SSH connectivity"
    @echo "  2. Setup SSH host keys (generate or retrieve from pass)"
    @echo "  3. Generate age keys for SOPS encryption"
    @echo "  4. Run nixos-anywhere to deploy NixOS"

# Show all hosts that can be bootstrapped
bootstrap-targets:
    @echo "🎯 Available bootstrap targets:"
    @echo "NixOS configurations that can be bootstrapped:"
    @nix eval --json .#nixosConfigurations --apply builtins.attrNames | jq -r '.[]' | grep -v "install-iso" | sed 's/^/  /'
