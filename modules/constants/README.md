# constants/

Shared facts, declared once and set once.

- `_options.nix`: the option tree, with types and descriptions. It's a plain module, which is why it has the `_` prefix.
- `constants.nix`: the top-level `config.constants` option, and the read-only mirror `flake.modules.generic.constants`. The mirror goes into every nixos, darwin and home-manager configuration through `plumbing`.
- `<area>.nix`: the values, one file per area (`locale.nix`, `media.nix`, …).

Reading constants:
- Flake-level code (`infra/*`, hosts, deploy) reads `config.constants`.
- Inside class modules, read `config.constants` too. It's the same value.

Constants are facts, not settings. A feature applies a constant with `mkDefault`. A type or host that must deviate overrides the real option, never the constant (overriding the mirror is an evaluation error). Facts about one host are keyed by host: `constants.network.hosts.<name>.…`.

From `master`'s `lib/defaults`, each area moves in the milestone that first reads it:
- user, locale and persistence paths
- the LAN host registry
- domains, service ports, and provider/backup ids

Rules: [../README.md](../README.md).
