# Run `just --list` to see all recipes. Recipes use the dev shell tools
# directly when inside it and fall back to `nix develop` otherwise.

set shell := ["bash", "-euo", "pipefail", "-c"]

# Run a command in the dev shell unless already inside it
run := if env("IN_NIX_SHELL", "") == "" { "nix develop -c" } else { "" }

default:
    @just --list

# Format nix files (writes)
format *path=".":
    nix fmt {{ path }}

# Verify formatting (read-only)
format-check:
    nix fmt -- --fail-on-change

# Lint with statix and deadnix (read-only)
lint:
    {{ run }} statix check .
    {{ run }} deadnix --fail .

# Auto-fix lint issues
lint-fix:
    {{ run }} statix fix .
    {{ run }} deadnix --edit .

# CI-safe umbrella: formatting, lint, and the flake checks (stale flake.nix, eval tests)
check: format-check lint flake-check

flake-check:
    nix flake check

# Build a host's system without switching
build host:
    nix build .#nixosConfigurations.{{ host }}.config.system.build.toplevel

# Run a VM host's install test; needs x86_64 Linux with KVM
vm-test host:
    @if [ "$(uname -sm)" != "Linux x86_64" ]; then echo "install tests run in CI (x86_64 KVM)" >&2; exit 1; fi
    nix build .#checks.x86_64-linux.install-{{ host }} -L

# Regenerate flake.nix from the flake-file.inputs declarations
flake-write:
    nix run .#write-flake

# Update flake inputs (all, or the named ones)
update *input:
    nix flake update {{ input }}
