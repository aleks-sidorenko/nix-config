# nix/

Flake plumbing. No features live here.

- `flake-parts.nix`: the `systems` list.
- `modules.nix`: `flake.modules.<class>.<aspect>`. It replaces flake-parts' own module, adding a `key` so an aspect reached through several imports is evaluated once.
- `nixpkgs.nix`: `perSystem`'s nixpkgs, with its config (`allowUnfree`) and overlays (`pkgs.unstable`). Hosts and tests use this same instance, so class modules can't set `nixpkgs.config`. Future overlays go here.
- `hosts.nix`: `config.hosts.<name>`, the host registry. Each entry builds `flake.<class>Configurations.<name>` from `flake.modules.<class>.<name>` and a `host-<name>` check on its system.
- `plumbing.nix`: `config.plumbing.{nixos,darwin,homeManager}`, the modules the host builders add to every configuration. Add plumbing (never features) by appending to these lists.
- `home-manager.nix`: home-manager inside nixos/darwin hosts (`useGlobalPkgs`, `useUserPackages`). `plumbing.homeManager` becomes `sharedModules`.
- `formatter.nix`, `devshell.nix`: `nix fmt` and `nix develop`.
- `eval-tests.nix`: `config.evalTests`, run as `checks.<system>.eval`.
- `factory.nix`: declares `config.factory`. The factories themselves live with their callers (rule 12).

`deploy.nix` adds `hosts.<name>.deploy` and builds `flake.deploy.nodes` and the deploy-rs checks from it. sops-nix, disko and impermanence are imported by the features that use them (`security/sops`, the host, `system/disks/impermanence`).

Rules: [../README.md](../README.md).
