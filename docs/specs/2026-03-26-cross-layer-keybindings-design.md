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
| `Alt` | Navigate | `HJKL` (focus split), `1-9` (tab switch), `[/]` (tab cycle) |
| `Alt+Shift` | Structure | `HJKL` (create split), `N` (new tab), `Q` (close tab) |
| `Alt+Ctrl` | Modify | `HJKL` (resize split) |

**Prefix mode (`Ctrl+A`)** mirrors direct bindings for discoverability and provides additional commands (write-to-file, logical splits). Prefix bindings are supplementary — the direct `Alt`-based bindings are primary.

**Preserved non-Alt bindings** (standard conventions, not part of the Alt scheme):

| Binding | Action | Rationale |
|---|---|---|
| `Ctrl+Shift+C/V/A` | Copy/paste/select all | Terminal standard |
| `Ctrl+Shift+Enter` | Toggle split zoom | Modifier consistent with split creation |
| `Ctrl+Shift+\|/-` | New split right/down (logical) | Alternative to directional |
| `Ctrl+Enter` | Toggle fullscreen | Ctrl = display control |
| `Ctrl++/-/0` | Font size | Ctrl = display control |
| `Ctrl+,` / `Ctrl+Shift+,` | Open/reload config | Standard convention |
| `Shift+PageUp/Down` | Scroll | Standard convention |
| `Alt+F4` | Quit | Global convention |

### Editor Layer (Neovim)

`Ctrl` is the base modifier for direct shortcuts. `Leader` (Space) provides namespaced commands.

| Modifier | Action | Keys |
|---|---|---|
| `Ctrl+HJKL` | Navigate (window focus) | Works in normal + terminal mode |
| `Ctrl+Arrows` | Modify (window resize) | |
| `Ctrl+S` | Save | All modes |
| `Ctrl+X` | Close window | |

**Navigation bindings (new):**

| Binding | Action | Replaces |
|---|---|---|
| `H` | Line begin (`^`) | `Alt+[` (freed for Ghostty) |
| `L` | Line end (`$`) | `Alt+]` (freed for Ghostty) |
| `g[` | Line begin (`^`) | Alternative |
| `g]` | Line end (`$`) | Alternative |
| `g{` | File begin (`gg`) | `Alt+Shift+[` (freed for Ghostty) |
| `g}` | File end (`G`) | `Alt+Shift+]` (freed for Ghostty) |

**Buffer navigation:** Uses vim bracket convention exclusively — no Shift+key shortcuts.

| Binding | Action |
|---|---|
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

## Changes From Current Config

### Ghostty

| Change | Detail |
|---|---|
| Change | Split navigation: `Alt+Shift+HJKL` -> `Alt+HJKL` |
| Change | Split creation: `Ctrl+Shift+HJKL` -> `Alt+Shift+HJKL` |
| Change | Split resize: `Alt+Shift+Ctrl+HJKL` -> `Alt+Ctrl+HJKL` |
| Change | Tab switch: `Alt+Ctrl+1-9` -> `Alt+1-9` |
| Change | Tab new: `Alt+Ctrl+N` -> `Alt+Shift+N` |
| Change | Tab close: `Alt+Ctrl+Q` -> `Alt+Shift+Q` |
| Add | Tab cycle: `Alt+[` (prev), `Alt+]` (next) |
| Remove | `Ctrl+Shift+HJKL/Arrows` for split creation (moved to `Alt+Shift`) |
| Remove | `Alt+Shift+Arrows` for split navigation (moved to `Alt+Arrows`) |
| Remove | `Alt+Shift+Ctrl+Arrows` for split resize (moved to `Alt+Ctrl+Arrows`) |
| Preserve | `Ctrl+Shift+\|/-` (logical split), `Ctrl+Shift+C/V/A` (copy/paste), `Ctrl+Shift+Enter` (zoom), font/config/scroll bindings, prefix mode |

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
