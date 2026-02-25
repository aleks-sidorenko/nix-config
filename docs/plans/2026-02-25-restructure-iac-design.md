# Design: Restructure IaC and Clean Up Repository Structure

## Problem

The repository has several structural inconsistencies:

1. **Router IaC split across two locations**: `packages/router/` contains the terranix config, secrets, terraform state, and host definitions, while `modules/terraform/routeros/` contains the terraform modules. This splits one logical concept across two unrelated directories.

2. **IaC masquerading as a nix package**: `packages/router/` is auto-discovered by snowfall-lib as a package, but most of its contents (terraform state, secrets, host definitions, resource imports) are not part of any nix derivation. Only the backup script is a real package.

3. **Stray file**: `config.rsc` at the repo root is an obsolete MikroTik config from before the terranix migration.

4. **`modules/terraform/`** lives alongside `modules/nixos/`, `modules/home/`, and `modules/darwin/` but is conceptually different — it's not a nix module system.

5. **Future growth**: More IaC targets are planned. The current structure doesn't scale.

## Design

### 1. Create `infra/` top-level directory

Extract all infrastructure-as-code into a dedicated `infra/` directory:

```
infra/
  router/
    default.nix          # terranix derivation (mkTerranixDerivation call)
    hosts.nix            # host MAC addresses and network config
    imports.nix          # terraform resource ID imports
    secrets.yaml         # SOPS-encrypted secrets
    terraform.tfstate    # encrypted OpenTofu state
    modules/             # terraform modules (from modules/terraform/routeros/)
      bridge/
      capsman/
      dhcp/
      dns/
      firewall/
      interfaces/
      misc/
      provider/
      system/
```

Future IaC targets follow the same pattern: `infra/<target>/`.

### 2. Wire router package explicitly in flake.nix

Since `infra/` is not a snowfall-lib auto-discovered directory, the router derivation must be explicitly added to flake outputs. The justfile already invokes it as `nix run .#router`, so the output name stays the same.

### 3. Update internal path references

- `default.nix`: `terraformModulesPath` changes from `../../modules/terraform/routeros` to `./modules`
- `default.nix`: `stateDir` changes from `"packages/router"` to `"infra/router"`
- `default.nix`: `secretsFile` changes from `"packages/router/secrets.yaml"` to `"infra/router/secrets.yaml"`
- `.sops.yaml`: Update path regex for router secrets
- `justfile`: Update `router-secrets` path and help text references

### 4. Delete obsolete files

- `config.rsc` — obsolete MikroTik config replaced by terranix
- `modules/terraform/` — empty after moving routeros/ into infra/router/modules/

### 5. No changes to packages/

- `scripts/bootstrap/` — bootstrap scripts that run before nix is available
- `packages/nvim/` stays — it's a real nix derivation
- `packages/wallpapers/` stays — it's a real nix derivation

## Resulting top-level structure

```
.nix-config/
  flake.nix
  justfile
  .sops.yaml
  docs/
  homes/           # snowfall-lib: home-manager configs
  infra/           # NEW: infrastructure-as-code
    router/
  lib/             # snowfall-lib: library functions
  modules/         # snowfall-lib: nixos, home, darwin modules
    nixos/
    home/
    darwin/
  overlays/        # snowfall-lib: nixpkgs overlays
  packages/        # snowfall-lib: nix packages only
    install/
    nvim/
    wallpapers/
  scripts/         # shared utilities and bootstrap shell scripts
  shells/          # snowfall-lib: dev shells
  systems/         # snowfall-lib: system configurations
```

## Trade-offs

**Pros:**
- Clean separation: `packages/` = nix derivations, `infra/` = IaC
- Router concept consolidated in one directory
- Scales for additional IaC targets
- `modules/` stays pure (only nix module system directories)

**Cons:**
- `infra/` is not snowfall-lib auto-discovered; requires explicit flake.nix wiring
- Requires justfile and .sops.yaml path updates
