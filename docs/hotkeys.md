# Hotkeys Reference

Cross-layer keybinding scheme for Linux (Hyprland/GNOME) and macOS (AeroSpace), unified across window manager, terminal (Ghostty), and editor (Neovim).

**Design spec:** `docs/specs/2026-03-26-cross-layer-keybindings-design.md`

---

## Schema Overview

### Layer Ownership

Each layer owns one primary modifier. Bindings never cross layers.

```
┌─────────────────────────────────────────────────┐
│  Window Manager                                 │
│  Linux: Super    macOS: Alt+Cmd                 │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │  Terminal (Ghostty)                     │    │
│  │  Alt                                    │    │
│  │                                         │    │
│  │  ┌─────────────────────────────────┐    │    │
│  │  │  Editor (Neovim)                │    │    │
│  │  │  Ctrl + Leader (Space)          │    │    │
│  │  └─────────────────────────────────┘    │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

### Action Semantics

The same secondary modifier means the same action at every layer:

| Secondary | Meaning | WM example | Ghostty example |
|---|---|---|---|
| (none) | **Navigate** | `Super+HJKL` focus | `Alt+HJKL` focus split |
| `+Shift` | **Structure** | `Super+Shift+HJKL` swap | `Alt+Shift+HJKL` create split |
| `+Alt`/`+Ctrl` | **Modify** | `Super+Alt+HJKL` resize | `Alt+Ctrl+HJKL` resize split |

### Spatial Keys

Same everywhere:

- `H/J/K/L` — left/down/up/right
- `1-9, 0` — position 1-10
- `[/]` — previous/next
- `Arrows` — directional alternative

---

## Window Manager — Linux (Hyprland & GNOME)

### Window Management

| Action | Binding | Notes |
|---|---|---|
| Focus left/down/up/right | `Super+H/J/K/L` | Forge in GNOME |
| Swap window | `Super+Shift+H/J/K/L` | Forge swap in GNOME |
| Resize window | `Super+Alt+H/J/K/L` | `binde` in Hyprland, Forge resize in GNOME |
| Close window | `Super+Q` | |
| Close window (alt) | `Alt+F4` | |
| Fullscreen | `Super+F` | |

### Workspaces

| Action | Binding |
|---|---|
| Switch to workspace 1-9 | `Super+1-9` |
| Switch to workspace 10 | `Super+0` |
| Move window to workspace 1-9 | `Super+Shift+1-9` |
| Move window to workspace 10 | `Super+Shift+0` |

### Monitor (Hyprland)

| Action | Binding |
|---|---|
| Move workspace to monitor | `Super+Ctrl+H/J/K/L` |
| Focus monitor | `Super+Ctrl+Arrows` |

### Monitor (GNOME)

| Action | Binding |
|---|---|
| Move window to monitor | `Super+Shift+Arrows` |

### App Launchers & Utilities

| Action | Binding | Notes |
|---|---|---|
| Open terminal | `Super+T` / `Ctrl+Alt+T` | |
| App launcher | `Super+D` | Rofi (Hyprland), search-light (GNOME) |
| Keyboard layout | `Super+Space` | |
| Keyboard layout back | `Super+Shift+Space` | |
| Lock screen | `Super+Backspace` | |
| Power/logout menu | `Ctrl+Super+Backspace` | |

### Screenshots

| Action | Binding |
|---|---|
| Area screenshot | `Print` |
| Active window | `Shift+Print` |
| Full screen | `Ctrl+Print` |

### Hyprland-Only

| Action | Binding |
|---|---|
| Move window (directional) | `Alt+Ctrl+H/J/K/L` |
| Special workspace toggle | `Super+U` |
| Move to special workspace | `Super+Shift+U` |
| Scratchpad terminal | `Super+Shift+T` |
| Volume control | `Super+V` |
| Interactive resize | `Super+R` |
| Mouse move window | `Super+LMB` |
| Mouse resize window | `Super+RMB` |

### GNOME-Only

| Action | Binding |
|---|---|
| Workspace left/right | `Super+Alt+Left/Right` |
| Move to workspace left/right | `Super+Shift+Alt+Left/Right` |
| First/last workspace | `Super+Home/End` |
| Move to first/last workspace | `Super+Shift+Home/End` |
| Maximize / minimize | `Super+Up/Down` |
| App switching | `Super+Tab` / `Alt+Tab` |
| Group switching | `` Super+` `` / `` Alt+` `` |
| Window menu | `Alt+Space` |
| Toggle maximize | `Alt+F10` |
| Run dialog | `Alt+F2` |

---

## Window Manager — macOS (AeroSpace)

### Window Management

| Action | Binding | Linux equivalent |
|---|---|---|
| Focus left/down/up/right | `Alt+Cmd+H/J/K/L` | `Super+H/J/K/L` |
| Swap window | `Alt+Cmd+Shift+H/J/K/L` | `Super+Shift+H/J/K/L` |
| Resize window | `Ctrl+Cmd+H/J/K/L` | `Super+Alt+H/J/K/L` |
| Close window | `Alt+Cmd+Q` | `Super+Q` |
| Fullscreen | `Alt+Cmd+F` | `Super+F` |

### Workspaces

| Action | Binding | Linux equivalent |
|---|---|---|
| Switch to workspace 1-9 | `Alt+Cmd+1-9` | `Super+1-9` |
| Switch to workspace 10 | `Alt+Cmd+0` | `Super+0` |
| Move to workspace 1-9 | `Alt+Cmd+Shift+1-9` | `Super+Shift+1-9` |
| Move to workspace 10 | `Alt+Cmd+Shift+0` | `Super+Shift+0` |

### Monitor

| Action | Binding |
|---|---|
| Focus monitor left/right | `Ctrl+Cmd+Shift+Left/Right` |
| Move window to monitor | `Ctrl+Cmd+Shift+H/L` |

### Utilities

| Action | Binding | Linux equivalent |
|---|---|---|
| App launcher (Raycast) | `Alt+Cmd+D` | `Super+D` |

### Not Carried Over (macOS native)

- Terminal launch — Raycast or Spotlight
- Keyboard layout — macOS input source switcher
- Lock screen — `Ctrl+Cmd+Q` (macOS native)
- Screenshots — `Cmd+Shift+3/4/5` (macOS native)
- Media/brightness — hardware keys

---

## Terminal (Ghostty)

### Alt-Based Scheme

All direct Ghostty bindings use `Alt` as the base modifier.

#### Navigate (`Alt`)

| Action | Binding |
|---|---|
| Focus split left/down/up/right | `Alt+H/J/K/L` |
| Focus split (arrows) | `Alt+Arrows` |
| Switch to tab 1-8 | `Alt+1-8` |
| Switch to last tab | `Alt+9` |
| Previous tab | `Alt+[` |
| Next tab | `Alt+]` |

#### Structure (`Alt+Shift`)

| Action | Binding |
|---|---|
| Create split left/down/up/right | `Alt+Shift+H/J/K/L` |
| Create split (arrows) | `Alt+Shift+Arrows` |
| New split right (logical) | `Alt+Shift+\|` |
| New split down (logical) | `Alt+Shift+-` |
| New tab | `Alt+Shift+N` |
| Close tab | `Alt+Shift+Q` |
| New window | `Alt+Shift+W` |
| Close window | `Alt+Shift+X` |

#### Modify (`Alt+Ctrl`)

| Action | Binding |
|---|---|
| Resize split left/down/up/right | `Alt+Ctrl+H/J/K/L` |
| Resize split (arrows) | `Alt+Ctrl+Arrows` |
| Toggle split zoom | `Alt+Ctrl+Enter` |

### System Bindings (`Ctrl+Shift`)

OS boundary and system operations — not part of the Alt scheme.

| Action | Binding |
|---|---|
| Copy to clipboard | `Ctrl+Shift+C` |
| Paste from clipboard | `Ctrl+Shift+V` |
| Select all | `Ctrl+Shift+A` |
| Paste from selection | `Shift+Insert` |
| Copy to clipboard (alt) | `Ctrl+Insert` |
| Reload config | `Ctrl+Shift+,` |
| Command palette | `Ctrl+Shift+P` |
| Inspector | `Ctrl+Shift+I` |
| Jump to prompt prev/next | `Ctrl+Shift+PageUp/Down` |

### Display Bindings (`Ctrl`)

| Action | Binding |
|---|---|
| Toggle fullscreen | `Ctrl+Enter` |
| Increase font size | `Ctrl++` |
| Decrease font size | `Ctrl+-` |
| Reset font size | `Ctrl+0` |
| Open config | `Ctrl+,` |

### Other Conventions

| Action | Binding |
|---|---|
| Scroll page up/down | `Shift+PageUp/Down` |
| Scroll to top/bottom | `Shift+Home/End` |
| Adjust selection | `Shift+Arrows` |
| Quit | `Alt+F4` |
| Claude Code newline | `Shift+Enter` |

### Prefix Mode (`Ctrl+A`)

Prefix mode mirrors direct bindings and adds power-user commands.

| Binding | Action |
|---|---|
| `Prefix > H/J/K/L` | Focus split |
| `Prefix > [/]` | Focus prev/next split |
| `Prefix > Arrows` | Focus split |
| `Prefix > T > N` | New tab |
| `Prefix > T > Q` | Close tab |
| `Prefix > T > [/]` | Prev/next tab |
| `Prefix > W > N` | New window |
| `Prefix > W > Q` | Close window |
| `Prefix > \|` | New split right |
| `Prefix > -` | New split down |
| `Prefix > S` | Write screen to file (paste) |
| `Prefix > Shift+S` | Write screen to file (open) |
| `Prefix > Ctrl+S` | Write screen to file (copy) |
| `Prefix > B` | Write scrollback to file (paste) |
| `Prefix > Shift+B` | Write scrollback to file (open) |
| `Prefix > Ctrl+B` | Write scrollback to file (copy) |
| `Prefix > E` | Write selection to file (paste) |
| `Prefix > Shift+E` | Write selection to file (open) |
| `Prefix > Ctrl+E` | Write selection to file (copy) |

---

## Editor (Neovim)

### Window Navigation (`Ctrl`)

| Action | Binding | Modes |
|---|---|---|
| Focus left window | `Ctrl+H` | Normal, Terminal |
| Focus down window | `Ctrl+J` | Normal, Terminal |
| Focus up window | `Ctrl+K` | Normal, Terminal |
| Focus right window | `Ctrl+L` | Normal, Terminal |
| Resize (decrease height) | `Ctrl+Up` | Normal |
| Resize (increase height) | `Ctrl+Down` | Normal |
| Resize (increase width) | `Ctrl+Left` | Normal |
| Resize (decrease width) | `Ctrl+Right` | Normal |

### Line & File Navigation

| Action | Primary | Alternative | Vim native |
|---|---|---|---|
| Line begin | `H` | `g[` | `^` / `0` |
| Line end | `L` | `g]` | `$` |
| File begin | `g{` | — | `gg` |
| File end | `g}` | — | `G` |

`H` and `L` work in normal and visual mode. `g`-prefix bindings work in normal and visual mode.

### Buffer Navigation (Bracket Convention)

| Action | Binding |
|---|---|
| Next buffer | `]b` |
| Previous buffer | `[b` |
| Next diagnostic | `]d` |
| Previous diagnostic | `[d` |
| Next error | `]e` |
| Previous error | `[e` |
| Next warning | `]w` |
| Previous warning | `[w` |

### Buffer Management (`Leader+b`)

| Action | Binding |
|---|---|
| Delete buffer | `Leader+bq` |
| Toggle pin | `Leader+bp` |
| Close buffers left | `Leader+bl` |
| Close other buffers | `Leader+bo` |
| Close non-pinned | `Leader+bP` |

### Window Management (`Leader+w`)

| Action | Binding |
|---|---|
| Previous window | `Leader+wp` |
| Close window | `Leader+wq` |
| Close window (alt) | `Ctrl+X` |
| Split right | `Leader+w\|` or `Leader+\|` |
| Split below | `Leader+-` |

### Tab Management (`Leader+Tab`)

| Action | Binding |
|---|---|
| Last tab | `Leader+Tab+l` |
| First tab | `Leader+Tab+f` |
| New tab | `Leader+Tab+n` |
| Next tab | `Leader+Tab+]` |
| Close tab | `Leader+Tab+q` |
| Previous tab | `Leader+Tab+[` |

### General

| Action | Binding | Modes |
|---|---|---|
| Save file | `Ctrl+S` | All |
| Clear search | `Esc` | Normal, Insert |
| Redraw / clear hlsearch | `Leader+ur` | Normal |
| Line diagnostics | `Leader+cd` | Normal |
| Inspect position | `Leader+ui` | Normal |
| Enter normal mode (terminal) | `Esc Esc` | Terminal |
| Quit all | `Leader+qq` | Normal |
| Jump back | `Ctrl+[` | Normal |
| Jump forward | `Ctrl+]` | Normal |

### Search

| Action | Binding | Modes |
|---|---|---|
| Next search result | `n` | Normal, Visual, Operator |
| Previous search result | `N` | Normal, Visual, Operator |
