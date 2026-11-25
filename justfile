# Run `just --list` to see all recipes. Recipes use the dev shell tools
# directly when inside it and fall back to `nix develop` otherwise.

set shell := ["bash", "-euo", "pipefail", "-c"]
set script-interpreter := ["bash", "-euo", "pipefail"]

# Run a command in the dev shell unless already inside it
run := if env("IN_NIX_SHELL", "") == "" { "nix develop -c" } else { "" }

default:
    @just --list

# Format nix files (writes)
[group('check')]
format *path=".":
    nix fmt {{ path }}

# Verify formatting (read-only)
[group('check')]
format-check:
    nix fmt -- --fail-on-change

# Lint with statix and deadnix (read-only)
[group('check')]
lint:
    {{ run }} statix check .
    {{ run }} deadnix --fail .

# Auto-fix lint issues
[group('check')]
lint-fix:
    {{ run }} statix fix .
    {{ run }} deadnix --edit .

# CI-safe umbrella: formatting, lint, and the flake checks (stale flake.nix, eval tests)
[group('check')]
check: format-check lint flake-check

[group('check')]
flake-check:
    nix flake check

# Build a host's system without switching
[group('hosts')]
[script]
build host:
    kind=$(nix eval --raw .#darwinConfigurations --apply 'c: if c ? {{ host }} then "darwin" else "nixos"')
    if [ "$kind" = darwin ]; then
        nix build .#darwinConfigurations.{{ host }}.system
    else
        nix build .#nixosConfigurations.{{ host }}.config.system.build.toplevel
    fi

# Deploy a host with deploy-rs, building on the target (`--boot` to activate on next boot)
[group('hosts')]
deploy host *args:
    {{ run }} deploy .#{{ host }} --skip-checks --remote-build {{ args }}

# Run a VM host's install test; needs x86_64 Linux with KVM
[group('hosts')]
[no-exit-message]
vm-test host:
    @if [ "$(uname -sm)" != "Linux x86_64" ]; then echo "install tests run in CI (x86_64 KVM)" >&2; exit 1; fi
    nix build .#checks.x86_64-linux.install-{{ host }} -L

# Install a NixOS host from the installer image at <address>, keeping its identity in the repo
[group('bootstrap')]
bootstrap-nixos host address *args:
    nix run .#bootstrap -- nixos {{ host }} {{ address }} {{ args }}

# Give the Mac this runs on its identity from the repo, or adopt its own
[group('bootstrap')]
bootstrap-darwin host *args:
    nix run .#bootstrap -- darwin {{ host }} {{ args }}

# Print the hosts that build an image, one per line
[group('iso')]
_iso-hosts:
    @nix eval --raw .#nixosConfigurations --apply 'cs: builtins.concatStringsSep "\n" (builtins.filter (n: cs.${n}.config ? isoImage) (builtins.attrNames cs)) + "\n"'

# Print an ISO host's image filename; fails for a host that builds no image.
# Asked of the flake, never globbed: one image name can prefix another's.
[group('iso')]
[no-exit-message]
[script]
_iso-resolve host:
    known=$(just _iso-hosts)
    if ! grep -qx -- "{{ host }}" <<<"$known"; then
        echo "Unknown ISO host: {{ host }} (known: $(paste -sd ' ' <<<"$known"))" >&2
        exit 1
    fi
    nix eval --raw .#nixosConfigurations.{{ host }}.config.image.fileName

# Build an ISO host's image into result-iso/iso/ (Linux; use iso-fetch elsewhere); lists hosts without one
[group('iso')]
[no-exit-message]
[script]
iso-build host="":
    if [ -z "{{ host }}" ]; then just _iso-hosts; exit 0; fi
    just _iso-resolve {{ host }} >/dev/null
    if [ "$(uname -s)" != Linux ]; then
        echo "images build on Linux; use: just iso-fetch {{ host }}" >&2
        exit 1
    fi
    rm -rf result-iso
    nix build .#nixosConfigurations.{{ host }}.config.system.build.isoImage --out-link result-iso -L

# Download the image CI last built for an ISO host into result-iso/iso/; lists hosts without one
[group('iso')]
[no-exit-message]
[script]
iso-fetch host="":
    if [ -z "{{ host }}" ]; then just _iso-hosts; exit 0; fi
    just _iso-resolve {{ host }} >/dev/null
    # Only master's builds: without a run id gh takes the newest artifact from any branch.
    run=$(gh run list -w iso.yml -b master -s success -L 1 --json databaseId,headSha -q '.[0] | "\(.databaseId) \(.headSha)"')
    if [ -z "$run" ]; then
        echo "No successful iso.yml run on master; run: gh workflow run iso.yml" >&2
        exit 1
    fi
    read -r id sha <<<"$run"
    echo "Fetching {{ host }} from run $id (master at ${sha:0:7})" >&2
    rm -rf result-iso
    # A download cut short would leave a truncated image for iso-write.
    gh run download "$id" -n "{{ host }}" -D result-iso/iso || { rm -rf result-iso; exit 1; }

# Write an ISO host's built or fetched image to a whole USB or removable disk (destroys it); lists hosts without one
[group('iso')]
[no-exit-message]
[script]
iso-write host="" device="":
    if [ -z "{{ host }}" ]; then just _iso-hosts; exit 0; fi
    if [ -z "{{ device }}" ]; then echo "Usage: just iso-write {{ host }} <device>" >&2; exit 1; fi
    file=$(just _iso-resolve {{ host }})
    nix run .#iso-write -- "result-iso/iso/$file" {{ device }}

# Regenerate flake.nix from the flake-file.inputs declarations
[group('flake')]
flake-write:
    nix run .#write-flake

# Regenerate .sops.yaml from the hosts and their keys under secrets/hosts
[group('flake')]
sops-write:
    nix run .#write-sops

# Update flake inputs (all, or the named ones)
[group('flake')]
update *input:
    nix flake update {{ input }}

# Print a stack's rendered OpenTofu config
[group('infra')]
infra-show stack:
    {{ run }} jq . "$(nix build --no-link --print-out-paths .#{{ stack }}.config)"

# Validate a stack's config against its providers (every stack when omitted); needs its secrets
[group('infra')]
[script]
infra-validate stack="":
    stacks="{{ stack }}"
    if [ -z "$stacks" ]; then
        stacks=$(nix eval --raw .#terranixModules --apply 'm: toString (builtins.attrNames m)')
    fi
    for s in $stacks; do
        nix run .#"$s".init -- -input=false
        nix run .#"$s".terraform -- validate
    done

# Plan a stack's changes
[group('infra')]
infra-plan stack *args:
    nix run .#{{ stack }}.plan -- {{ args }}

# Apply a stack's changes
[group('infra')]
infra-apply stack *args:
    nix run .#{{ stack }}.apply -- {{ args }}

# Destroy a stack's resources (prevent_destroy still guards adopted ones)
[group('infra')]
infra-destroy stack *args:
    nix run .#{{ stack }}.destroy -- {{ args }}

# Edit a stack's secrets, or the provider credentials stacks share when omitted
[group('infra')]
infra-secrets-edit stack="":
    mkdir -p infra/{{ stack }}
    {{ run }} sops infra/{{ if stack == "" { "" } else { stack + "/" } }}secrets.yaml
