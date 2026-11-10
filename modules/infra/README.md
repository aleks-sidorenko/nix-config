# infra/

Terranix/OpenTofu stacks, one directory each: `router/`, `dns/`, `storage/`, `tailnet/` (from the repo-root `infra/` on `master`).

Each stack contains:
- a flake-parts module that defines its `perSystem.packages` (the terranix derivation plus its plan/apply/backup scripts) for the `just <stack>-*` recipes
- `_`-prefixed terranix configs (`_config.nix`, `_imports.nix`), which import-tree skips
- `secrets.yaml` and `terraform.tfstate`, which import-tree ignores because they aren't `.nix`

Stacks read `config.constants` directly (the LAN registry, domains, backup ids). Data derived from hosts (dns names, tailnet tags) comes from a collector option that hosts add to, instead of evaluating every system. The shared provider credentials file becomes `secrets/infra.yaml`.

These stacks move in milestone 6. Copy them fresh from `master` then, because `master` keeps changing their state.

Rules: [../README.md](../README.md).
