# Keybinding Contract: Ghostty ↔ Neovim

**Date:** 2026-08-17
**Status:** Approved
**Repos affected:** `nix-config` (Ghostty), `nix-nvim` (Neovim)

## Problem

Ghostty (the terminal emulator) receives every keystroke **first**. Any chord it
binds is stolen from the program running inside it — Neovim, the shell, any TUI.
Conversely, any chord Ghostty leaves alone flows through to the running program
(Ghostty speaks the Kitty keyboard protocol, so Neovim can even distinguish
`C-,`, `C-S-[`, etc. — but only for chords Ghostty does not intercept first).

Concrete symptom: `C--` and `C-|` cannot be used for splits inside Telescope,
because Ghostty binds `ctrl+-` (decrease font size) and grabs it before Neovim
sees it.

The existing setup is already ~80% coherent, but a few Ghostty bindings leak into
bare-`Ctrl` / `Ctrl+symbol` territory and steal keys Neovim wants, and the
implicit ownership rule is undocumented, so future bindings drift into
collisions.

## The Contract (durable rule)

Modifier space is owned by layer, not contested:

| Layer | Owner | Scope |
|---|---|---|
| **Alt / Alt+Shift / Alt+Ctrl** | Ghostty | All terminal-owned actions: pane focus/create/resize, tab & window management, font size, fullscreen. Neovim never uses Alt. |
| **Ctrl+A prefix** | Ghostty | tmux-style prefix; rare actions live here (config/reload). |
| **bare Ctrl + Ctrl+Shift** | Neovim (running program) | Reserved for the program inside the terminal. In the **Ctrl+Shift-letter** space Ghostty binds only `ctrl+shift+{c,v,a,p,i,q}` for OS-conventional chrome (copy/paste/select/palette/inspector/quit). Additionally, a small set of non-letter conventional editing/scroll chords is sanctioned chrome (see "Kept as-is" below). Everything else in this space passes through untouched. |
| **Leader (Space)** | Neovim | Editor commands; never reaches the terminal, always safe. |

### Shared mnemonics — constant letters, modifier signals the target

- `hjkl` = directional → **Alt** = terminal splits, **Ctrl** = editor windows
- `[` / `]` = previous / next (tabs, buffers, jumps, diagnostics)
- `-` / `|` = split → **Alt+Shift** = terminal split, **Ctrl** = editor/picker split

This is why muscle memory is unified without collision: the same letters mean the
same thing in both apps; only the modifier changes, and the modifier tells you
which app you are talking to.

## Changes

### Ghostty (`nix-config/modules/home/cli/terminals/ghostty/default.nix`)

Evict the bare-`Ctrl` offenders out of Neovim's reserved space:

| Current (steals from Neovim) | New | Rationale |
|---|---|---|
| `ctrl+-` / `ctrl++` / `ctrl+0` (font size) | `alt+-` / `alt+=` / `alt+0` | Font is a terminal-display concern → Alt bucket. Frees `C--` / `C-+` / `C-0`. `alt+-/=/0` are currently unbound. |
| `ctrl+enter` (fullscreen) | `alt+enter` | Frees `C-enter`. `alt+ctrl+enter` (split zoom) is untouched. |
| `ctrl+;` / `ctrl+shift+;` (config / reload) | `ctrl+a>c` / `ctrl+a>r` (prefix) | Config is rare → belongs in the prefix. Frees `C-;` entirely. `c` / `r` are unused prefix subkeys. |

**Kept as-is** (conventional terminal chrome, no Neovim collision — sanctioned
under the contract):
- `ctrl+shift+c/v/a` (copy/paste/select), `ctrl+shift+p` (palette),
  `ctrl+shift+i` (inspector), `ctrl+shift+q` (quit)
- `ctrl+insert` (copy) / `shift+insert` (paste) — conventional editing chords
- `shift+page_up/down`, `shift+home/end`, `shift+arrow_*` — scroll / selection
- The `ctrl+a>` write-to-file block (screen/scrollback/selection) — lives under
  the prefix, does not touch Neovim's space
- `shift+enter` (Claude Code passthrough)

**Explicitly untouched:** every existing binding not named in the eviction table
above stays exactly as-is. This refactor only *evicts the three offenders*
(font / fullscreen / config) and *refreshes comments* — it does not prune or
re-home any other binding. `ctrl+insert` is retained as sanctioned chrome, not
treated as a contract violation.

Refresh the inline comments so they document the contract above, not just the
old workaround.

### Neovim (`nix-nvim`)

**Telescope** (`nvim/plugins/navigation/telescope.nix`) — in *both* insert and
normal mode:
- `C--` = open selection in horizontal split (`select_horizontal`)
- `C-|` = open selection in vertical split (`select_vertical`)
- Remove the bare `-` / `|` normal-mode split hack.
- Additive: the Telescope default insert-mode splits (`C-v` / `C-x`) are
  **retained**; `C--` / `C-|` are added alongside them, not replacements.
- Drop the "Ghostty intercepts C-|/C--" comment — no longer true.

**keymaps** (`nvim/keymaps.nix`) — add window split-create alongside the existing
`<leader>-` / `<leader>|` (keep those as the discoverable path; `C-` is the fast
path):
- `C--` = horizontal split (`<C-w>s`)
- `C-|` = vertical split (`<C-w>v`)

## Risks / verification

Build success is not sufficient; these need an end-to-end check in a live
Ghostty+Neovim session:

- **First implementation step for the Neovim side must be pinning the working
  notation** for `C--` / `C-|` via a live Kitty-protocol test (`:map`, or
  observing received keycodes) — every other Neovim edit depends on it.
  Candidate notations: `<C-->` for `C--`; `<C-|>` / `<C-Bslash>` / `<C-S-\>` for
  `C-|` (recall `C-|` is physically `ctrl+shift+\`).
  **Fallback if `C-|` proves undeliverable** through the Kitty protocol: keep
  `C--` for horizontal split and use `C-\` (bare, no shift) for vertical split,
  documenting the deviation. Do not silently drop the binding.
- Confirm the evicted chords (`C--`, `C-+`, `C-0`, `C-enter`, `C-;`) actually
  pass through to Neovim after eviction, and that the relocated Ghostty actions
  (`alt+-/=/0`, `alt+enter`, `ctrl+a>c/r`) fire.

## Out of scope

- No re-derivation of the Alt-family terminal scheme (nav/create/resize) — it is
  already coherent and stays as-is.
- No changes to `hjkl` window nav or `[`/`]` prev/next bindings.
- No unrelated keymap refactoring.

## Logistics

Two separate git repos → two branches, two commits:
- `nix-config`: branch `refactor/keybinding-contract` (Ghostty edits + this spec)
- `nix-nvim`: branch `refactor/keybinding-contract` (Telescope + keymaps edits)
