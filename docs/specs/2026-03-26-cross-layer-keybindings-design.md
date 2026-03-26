# Cross-Layer Keybinding Scheme

## Goal

Define a consistent keybinding scheme across all three layers — window manager (Hyprland, GNOME, AeroSpace), terminal (Ghostty), and editor (Neovim) — so that muscle memory transfers across layers and platforms (Linux and macOS).

## Design Principles

### 1. One Modifier Per Layer

Each layer owns a primary modifier. No two layers share the same base modifier:

| Layer | Linux Modifier | macOS Modifier |
|---|---|---|
| Window Manager | `Super` | `Alt+Cmd` |
| Terminal (Ghostty) | `Alt` | `Alt` |
| Editor (Neovim) | `Ctrl` | `Ctrl` |

### 2. Consistent Action Semantics

Within every layer, the same secondary modifier means the same action:

| Secondary | Meaning | Example |
|---|---|---|
| (none) | **Navigate** — go somewhere | Focus window, focus split, focus nvim pane |
| `+Shift` | **Structure** — add, remove, move | Swap window, create split, new tab |
| `+Alt` or `+Ctrl` | **Modify** — change properties | Resize window, resize split |

### 3. Spatial Consistency

The same keys always mean the same spatial directions across all layers:

- `h/j/k/l` — left/down/up/right (vim convention)
- `1-9, 0` — workspace/tab 1-10
- `[/]` — previous/next (sequential)

## Layer Ownership

### Window Manager Layer

**Linux:** `Super` is the base modifier. `Super` never reaches terminal or editor.

| Modifier | Action | Keys |
|---|---|---|
| `Super` | Navigate (focus) | `HJKL`, `1-9,0` |
| `Super+Shift` | Structure (swap, move) | `HJKL`, `1-9,0` |
| `Super+Alt` | Modify (resize) | `HJKL` |
| `Super+Ctrl` | Monitor ops | `HJKL` (move ws), `Arrows` (focus) |

**macOS (AeroSpace):** `Alt+Cmd` replaces `Super`.

| Modifier | Action | Keys |
|---|---|---|
| `Alt+Cmd` | Navigate (focus) | `HJKL`, `1-9,0` |
| `Alt+Cmd+Shift` | Structure (swap, move) | `HJKL`, `1-9,0` |
| `Ctrl+Cmd` | Modify (resize) | `HJKL` |
| `Ctrl+Cmd+Shift` | Monitor ops | `Arrows` (focus), `H/L` (move) |

### Terminal Layer (Ghostty)

`Alt` is the base modifier. Ghostty intercepts before the inner application.

| Modifier | Action | Keys |
|---|---|---|
| `Alt` | Navigate | `HJKL` (focus split), `1-9` (tab switch), `[/]` (tab cycle), `PageUp/Down` (jump to prompt) |
| `Alt+Shift` | Structure | `HJKL` (create split), `\|/-` (logical split), `N` (new tab), `Q` (close tab), `W` (new window), `X` (close window) |
| `Alt+Ctrl` | Modify | `HJKL` (resize split), `Enter` (toggle split zoom) |

**Letter conventions within `Alt+Shift`:** the key identifies the target or action — `N`(ew tab), `Q`(uit tab), `W`(indow new), `X`(close window), `HJKL`(direction).

**Prefix mode (`Ctrl+A`)** mirrors direct bindings for discoverability and provides additional commands (write-to-file). Prefix bindings are supplementary — the direct `Alt`-based bindings are primary.

**Non-Alt bindings** use two namespaces outside the Alt scheme:

`Ctrl+Shift` = system/OS boundary operations:

| Binding | Action | Rationale |
|---|---|---|
| `Ctrl+Shift+C/V/A` | Copy/paste/select all | Terminal-universal clipboard standard |
| `Ctrl+Shift+,` | Reload config | System operation |
| `Ctrl+Shift+P` | Command palette | System operation |
| `Ctrl+Shift+I` | Inspector | System operation |

`Ctrl` = display control:

| Binding | Action |
|---|---|
| `Ctrl+Enter` | Toggle fullscreen |
| `Ctrl++/-/0` | Font size |
| `Ctrl+,` | Open config |

Other conventions:

| Binding | Action |
|---|---|
| `Shift+PageUp/Down` | Scroll page |
| `Shift+Home/End` | Scroll to top/bottom |
| `Shift+Arrows` | Adjust selection |
| `Shift+Insert` / `Ctrl+Insert` | Paste/copy (X11) |
| `Alt+F4` | Quit (global) |

### Editor Layer (Neovim)

`Ctrl` is the base modifier for direct shortcuts. `Leader` (Space) provides namespaced commands.

| Modifier | Action | Keys |
|---|---|---|
| `Ctrl+HJKL` | Navigate (window focus) | Works in normal + terminal mode |
| `Ctrl+Arrows` | Modify (window resize) | Arrows because HJKL is taken for navigate; Ctrl+Shift/Alt intercepted by Ghostty |
| `Ctrl+S` | Save | All modes |

**Navigation bindings (new):**

| Binding | Action | Replaces |
|---|---|---|
| `H` | Line begin (`^`) | `Alt+[` (freed for Ghostty) |
| `L` | Line end (`$`) | `Alt+]` (freed for Ghostty) |
| `g[` | Line begin (`^`) | Alternative |
| `g]` | Line end (`$`) | Alternative |
| `g{` | File begin (`gg`) | `Alt+Shift+[` (freed for Ghostty) |
| `g}` | File end (`G`) | `Alt+Shift+]` (freed for Ghostty) |

**Buffer navigation:** Uses vim bracket convention for cycling, `Leader+number` for direct access (mirrors Ghostty `Alt+1-9` for tabs).

| Binding | Action |
|---|---|
| `Leader+1-9` | Go to buffer 1-9 |
| `]b` / `[b` | Next/prev buffer |
| `]d` / `[d` | Next/prev diagnostic |
| `]e` / `[e` | Next/prev error |
| `]w` / `[w` | Next/prev warning |
| `Leader+bq` | Delete buffer |
| `Leader+bp` | Toggle pin |
| `Leader+bo` | Close other buffers |

**Removed bindings:**

| Old Binding | Was | Why |
|---|---|---|
| `Alt+J/K` | Move line down/up | Conflicts with Ghostty `Alt+HJKL` |
| `Alt+[/]` | Line begin/end | Conflicts with Ghostty `Alt+[/]` |
| `Alt+Shift+[/]` | File begin/end | Conflicts with Ghostty `Alt+Shift` layer |
| `Shift+H/L` | Buffer cycle (duplicate) | Frees H/L for line begin/end; `]b`/`[b` already exists |
| `Shift+X` | Delete buffer (duplicate) | `Leader+bq` already exists |
| `Ctrl+X` | Close window | Structural action on navigate modifier; `Leader+wq` exists |

## Changes From Current Config

### Ghostty

| Change | Detail |
|---|---|
| Change | Split navigation: `Alt+Shift+HJKL` -> `Alt+HJKL` |
| Change | Split creation: `Ctrl+Shift+HJKL` -> `Alt+Shift+HJKL` |
| Change | Split resize: `Alt+Shift+Ctrl+HJKL` -> `Alt+Ctrl+HJKL` |
| Change | Logical split: `Ctrl+Shift+\|/-` -> `Alt+Shift+\|/-` |
| Change | Split zoom: `Ctrl+Shift+Enter` -> `Alt+Ctrl+Enter` |
| Change | Tab switch: `Alt+Ctrl+1-9` -> `Alt+1-9` |
| Change | Tab new: `Alt+Ctrl+N` -> `Alt+Shift+N` |
| Change | Tab close: `Alt+Ctrl+Q` -> `Alt+Shift+Q` |
| Change | New window: `Ctrl+Shift+N` -> `Alt+Shift+W` |
| Change | Close window: `Ctrl+Shift+Q` -> `Alt+Shift+X` |
| Change | Jump to prompt: `Ctrl+Shift+PageUp/Down` -> `Alt+PageUp/Down` |
| Add | Tab cycle: `Alt+[` (prev), `Alt+]` (next) |
| Remove | `Ctrl+Shift+HJKL/Arrows` for split creation (moved to `Alt+Shift`) |
| Remove | `Alt+Shift+Arrows` for split navigation (moved to `Alt+Arrows`) |
| Remove | `Alt+Shift+Ctrl+Arrows` for split resize (moved to `Alt+Ctrl+Arrows`) |
| Remove | `Ctrl+Shift+N/Q` for window new/close (moved to `Alt+Shift+W/X`) |
| Remove | `Ctrl+Shift+Enter` for zoom (moved to `Alt+Ctrl+Enter`) |
| Remove | `Ctrl+Shift+PageUp/Down` for prompt jump (moved to `Alt+PageUp/Down`) |
| Preserve | `Ctrl+Shift+C/V/A` (clipboard), `Ctrl+Shift+,/P/I` (config/system), font/scroll bindings, prefix mode |

### Neovim

| Change | Detail |
|---|---|
| Remove | `Alt+J/K` (line move) — conflicts with Ghostty |
| Remove | `Alt+[/]` (line begin/end) — conflicts with Ghostty |
| Remove | `Alt+Shift+[/]` (file begin/end) — conflicts with Ghostty |
| Remove | `Shift+H/L` (buffer cycle duplicate) — frees H/L |
| Remove | `Shift+X` (buffer delete duplicate) — use `Leader+bq` |
| Add | `H` -> line begin (`^`), `L` -> line end (`$`) |
| Add | `g[`/`g]` -> line begin/end (alternative) |
| Add | `g{`/`g}` -> file begin/end |
| Add | `Leader+1-9` -> go to buffer 1-9 (mirrors Ghostty `Alt+1-9`) |
| Remove | `Ctrl+X` (close window) — semantic mismatch, use `Leader+wq` |

### Hyprland

No changes from the existing unified-keybindings spec. See `docs/specs/2026-03-26-unified-keybindings-design.md`.

### GNOME

No changes from the existing unified-keybindings spec. See `docs/specs/2026-03-26-unified-keybindings-design.md`.

### AeroSpace

No changes from the existing AeroSpace spec. See `docs/specs/2026-03-26-aerospace-macos-tiling-design.md`.

## Conflict Matrix

Verification that no two layers share the same binding:

| Modifier combo | Owner | Conflicts? |
|---|---|---|
| `Alt+letter/number` | Ghostty (navigate) | Neovim Alt bindings removed |
| `Alt+Shift+letter` | Ghostty (structure) | Neovim Alt+Shift bindings removed |
| `Alt+Ctrl+letter` | Ghostty (modify) | No Neovim bindings here |
| `Ctrl+letter` | Neovim | Ghostty uses `Ctrl+Shift` (different) |
| `Ctrl+Shift+letter` | Ghostty (copy/paste, config) | No Neovim bindings here |
| `Super+*` (Linux) | WM | Never reaches terminal/editor |
| `Alt+Cmd+*` (macOS) | WM (AeroSpace) | Never reaches terminal/editor |
| `Ctrl+Cmd+*` (macOS) | WM (AeroSpace) | Never reaches terminal/editor |

## Files to Modify

### Ghostty
- `modules/home/cli/terminals/ghostty/default.nix` — update keybind array

### Neovim
- `packages/nvim/keymaps.nix` — remove Alt bindings, add H/L and g-prefix bindings
- `packages/nvim/plugins/ui/bufferline.nix` — remove Shift+H/L/X duplicates

### Hyprland
- `modules/home/desktops/hyprland/keybindings.nix` — per existing spec

### GNOME
- `modules/home/desktops/gnome/keybindings.nix` — per existing spec

### AeroSpace
- `modules/home/desktops/aerospace/keybindings.nix` — per existing spec
