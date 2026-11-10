# cli/

Command-line environment.

| Path | Features (from `master`) |
|---|---|
| `fish/` | `fish`, the one shell |
| `nvim/` | `nvim`, the one editor |
| `ghostty/` | `ghostty`, the one terminal |
| `tools/` | `archivers`, `atuin`, `bat`, `bottom`, `coreutils`, `direnv`, `disk-report`, `eza`, `fzf`, `gh`, `git`, `htop`, `modern-unix`, `moreutils`, `network-tools`, `nh`, `nix-index`, `pdf`, `starship`, `yazi`, `zellij`, `zoxide` |

**One of each, no selectors.** `master` has several shells (fish, zsh) and a separate `default` module in each of `shells/`, `editors/` and `terminals/` to choose between them. Only one of each is used, so the rewrite keeps just that one and drops the selectors.
- `fish` makes itself the shell: it enables `programs.fish` and sets the users' login shell. `system-common` imports it.
- `nvim` sets itself as `EDITOR`, and `ghostty` as the terminal.
- There's no `shells/`, `editors/` or `terminals/` group, and no `zsh`, `default-shell`, `default-editor` or `default-terminal`.
- Apps work the same way (see `../apps/README.md`).
- If a second shell is ever needed, it gets its own feature, and the choice becomes a setting then.

Examples:
- `nixos/cli/shells/fish` + `darwin/cli/shells/fish` + `home/cli/shells/fish` → `cli/fish/`, aspect `fish`.
- `*/cli/shells/default`, `home/cli/shells/zsh` → not ported.
- `home/cli/editors/nvim` → `cli/nvim/`, aspect `nvim`.
- `darwin/cli/tools/coreutils` + `home/cli/tools/coreutils` → `cli/tools/coreutils/`, aspect `coreutils`.
- `home/cli/tools/disk-report` + repo-root `packages/disk-report` → `cli/tools/disk-report/` (`disk-report.nix` + `_package.nix`), aspect `disk-report`.

Rules: [../README.md](../README.md).
