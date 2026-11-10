# cli/

Command-line environment.

| Sub-directory | Features (from `master`) |
|---|---|
| `shells/` | `fish`, `zsh`, `default-shell` |
| `editors/` | `nvim`, `default-editor` |
| `terminals/` | `ghostty`, `default-terminal` |
| `tools/` | `archivers`, `atuin`, `bat`, `bottom`, `coreutils`, `direnv`, `disk-report`, `eza`, `fzf`, `gh`, `git`, `htop`, `modern-unix`, `moreutils`, `network-tools`, `nh`, `nix-index`, `nix-ld`, `pdf`, `starship`, `yazi`, `zellij`, `zoxide` |

**`default` selectors.** Today these are separate modules: `cli/shells/default`, `cli/editors/default` and `cli/terminals/default`. Each becomes a `default-<x>` feature that owns the setting:
- `default-shell` declares `nix-config.cli.shells.default`, and applies it as the users' login shell.
- Each shell feature imports `default-shell` and sets itself with `mkDefault`.
- Editors and terminals work the same way, and so do `apps/browsers` (`default-browser`), `apps/media` (`default-player`) and `apps/productivity` (`default-office`).

Examples:
- `nixos/cli/shells/fish` + `darwin/cli/shells/fish` + `home/cli/shells/fish` → `cli/shells/fish/`, aspect `fish`.
- `home/cli/shells/default` → `cli/shells/default-shell/`, aspect `default-shell`.
- `darwin/cli/tools/coreutils` + `home/cli/tools/coreutils` → `cli/tools/coreutils/`, aspect `coreutils`.

Rules: [../README.md](../README.md).
