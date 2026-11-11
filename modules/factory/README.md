# factory/

`config.factory.*` holds functions that build per-class modules. It's a top-level option, not a flake output.

`user.nix`: `config.factory.user { name; admin ? false; }` returns `{ nixos; darwin; }`.
- **nixos:** a normal user, plus `wheel` when admin.
- **darwin:** the account's home (`/Users/<name>`).
- **both:** `home-manager.users.<name>` imports `flake.modules.homeManager.<name>` when that exists.

`users/<name>/` calls it. Later milestones extend it with what `master`'s `nix-config.users` does: primary, profile, SOPS password, identity. The login shell comes from the `fish` feature, not the factory.

`arr.nix`: `config.factory.arr { name; title; userDescription; dataDir ? "/var/lib/<name>"; }` returns the nixos module radarr, sonarr and prowlarr share: the `service-<name>-api-key` secret, the `config.xml` SOPS template (bound to loopback) installed by `preStart`, a system user in `media`, the upstream service with its firewall closed, and an nginx vhost behind the htpasswd. The features add the upstream user, group, data dir and port themselves.

Rules: [../README.md](../README.md).
