# users/

One feature per person, built with `config.factory.user` (see `../factory/`), plus profiles.

| Sub-directory | From `master` |
|---|---|
| `<name>/` | `alexander`, `oleksandrsy`, and their homes in `homes/*/<user>@<host>` (the person's part) |
| `profiles/` | `adult`, `child`: `nixos/users/child-lockdown`, `home/roles/child`, `home/desktops/gnome/profiles/*` |

A user feature sets `flake.modules.{nixos,darwin}.<name>` from the factory, and its own `flake.modules.homeManager.<name>`. Settings tied to one machine (e.g. the workbook's monitor layout) stay in `../hosts/<host>/`.

Public key material stays in the repo-root `identities/<name>/`. The `identity` feature resolves it.

Examples:
- `nixos/users/child-lockdown` → `users/profiles/child/`, aspect `child`.
- `homes/aarch64-darwin/oleksandrsy@workbook` → `users/oleksandrsy/` (person) + `hosts/workbook/` (machine-only settings).

Rules: [../README.md](../README.md).
