# factory/

`config.factory.*` holds functions that build per-class modules. It's a top-level option, not a flake output.

`user.nix`: `config.factory.user { name; admin ? false; }` returns `{ nixos; darwin; }`.
- **nixos:** a normal user, plus `wheel` when admin.
- **darwin:** the account's home (`/Users/<name>`).
- **both:** `home-manager.users.<name>` imports `flake.modules.homeManager.<name>` when that exists.

`users/<name>/` calls it. Later milestones extend it with what `master`'s `nix-config.users` does: primary, profile, SOPS password, identity. The login shell comes from the `fish` feature, not the factory.

Rules: [../README.md](../README.md).
