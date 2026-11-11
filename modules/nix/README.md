# nix/

Flake plumbing. No features live here.

- `flake-parts.nix`: the `systems` list.
- `modules.nix`: `flake.modules.<class>.<aspect>`. It replaces flake-parts' own module, adding a `key` so an aspect reached through several imports is evaluated once.
- `nixpkgs.nix`: the nixpkgs config (`allowUnfree`) and overlays (`pkgs.unstable`), defined once for every host and for `perSystem`. Future overlays go here.
- `plumbing.nix`: `config.plumbing.{nixos,darwin,homeManager}`, the modules the host builders add to every configuration. Add plumbing (never features) by appending to these lists.
- `home-manager.nix`: home-manager inside nixos/darwin hosts (`useGlobalPkgs`, `useUserPackages`). `plumbing.homeManager` becomes `sharedModules`.
- `formatter.nix`, `devshell.nix`: `nix fmt` and `nix develop`.
- `eval-tests.nix`: `config.evalTests`, run as `checks.<system>.eval`.

`deploy.nix` declares `flake.deploy.nodes` (each host adds its own node) and the deploy-rs checks. sops-nix, disko and impermanence are imported by the features that use them (`security/sops`, the host, `system/disks/impermanence`).

Rules: [../README.md](../README.md).
