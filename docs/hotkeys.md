# Hotkeys Reference

Cross-layer keybinding scheme for Linux (Hyprland/GNOME) and macOS (AeroSpace), unified across window manager, terminal (Ghostty), and editor (Neovim).

**Design spec:** `docs/specs/2026-03-26-cross-layer-keybindings-design.md`

---

## Legend

| Symbol     | Meaning                                   |
| ---------- | ----------------------------------------- |
| `Leader`   | `Space` key (Neovim leader)               |
| `Prefix`   | `Ctrl+A` (Ghostty prefix mode)            |
| `Super`    | Windows/Meta key (Linux)                  |
| `Alt+Cmd`  | macOS equivalent of `Super` (AeroSpace)   |
| `Ctrl+Cmd` | macOS modifier (AeroSpace resize/monitor) |

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

**Arrows resize; HJKL do everything else.** This is the Neovim model
(`Ctrl+HJKL` focuses, `Ctrl+Arrows` resizes) lifted to every layer, so the
muscle memory is identical everywhere: *HJKL move focus, arrows resize* — only
the base modifier changes per layer. Each action binds exactly one spatial key
set (no HJKL/arrow duplicates), keeping the other combinations free.

| Spatial keys | Meaning       | Neovim          | Ghostty          | AeroSpace            | Hyprland            | GNOME               |
| ------------ | ------------- | --------------- | ---------------- | -------------------- | ------------------- | ------------------- |
| HJKL         | **Navigate**  | `Ctrl+HJKL`     | `Alt+HJKL`       | `Alt+Cmd+HJKL`       | `Super+HJKL`        | `Super+HJKL`        |
| HJKL + move  | **Structure** | `Ctrl+Alt+HJKL` | `Alt+Shift+\|/-` | `Alt+Cmd+Shift+HJKL` | `Super+Shift+HJKL`  | `Super+Shift+HJKL`  |
| Arrows       | **Resize**    | `Ctrl+Arrows`   | `Alt+Arrows`     | `Ctrl+Cmd+Arrows`    | `Super+Alt+Arrows`  | `Super+Ctrl+Arrows` |

The resize modifier differs per WM (AeroSpace `Ctrl+Cmd`, Hyprland `Super+Alt`,
GNOME `Super+Ctrl`) because each WM already reserves other arrow tiers for
workspaces, monitors, and maximize/minimize — but the arrow keys always mean
resize.

### Spatial Keys

- `H/J/K/L` — left/down/up/right (focus and structural moves)
- `Arrows` — resize (left = wider, right = narrower, up = shorter, down = taller)
- `1-9, 0` — position 1-10
- `[/]` — previous/next

---

## Window Manager — Linux (Hyprland & GNOME)

### Window Management

| Action                   | Binding               | Notes                                      |
| ------------------------ | --------------------- | ------------------------------------------ |
| Focus left/down/up/right | `Super+H/J/K/L`       | Forge in GNOME                             |
| Swap window              | `Super+Shift+H/J/K/L` | Forge swap in GNOME                        |
| Resize window            | `Super+Alt+Arrows` (Hyprland) · `Super+Ctrl+Arrows` (GNOME) | Arrows resize; frees `Super+Alt+HJKL` |
| Close window             | `Super+Q`             |                                            |
| Close window (alt)       | `Alt+F4`              |                                            |
| Fullscreen               | `Super+F`             |                                            |
| Toggle maximize          | `Super+M`             |                                            |

### Workspaces

| Action                       | Binding           |
| ---------------------------- | ----------------- |
| Switch to workspace 1-9      | `Super+1-9`       |
| Switch to workspace 10       | `Super+0`         |
| Move window to workspace 1-9 | `Super+Shift+1-9` |
| Move window to workspace 10  | `Super+Shift+0`   |

### Monitor (Hyprland)

| Action                    | Binding              |
| ------------------------- | -------------------- |
| Move workspace to monitor | `Super+Ctrl+H/J/K/L` |
| Focus monitor             | `Super+Ctrl+Arrows`  |

### Monitor (GNOME)

| Action                 | Binding              |
| ---------------------- | -------------------- |
| Move window to monitor | `Super+Shift+Arrows` |

### App Launchers & Utilities

| Action               | Binding                  | Notes                                 |
| -------------------- | ------------------------ | ------------------------------------- |
| Open terminal        | `Super+T` / `Ctrl+Alt+T` |                                       |
| App launcher         | `Super+D`                | Rofi (Hyprland), search-light (GNOME) |
| Keyboard layout      | `Super+Space`            |                                       |
| Keyboard layout back | `Super+Shift+Space`      |                                       |
| Lock screen          | `Super+Backspace`        |                                       |
| Power/logout menu    | `Ctrl+Super+Backspace`   |                                       |

### Screenshots

| Action          | Binding (Hyprland) | Binding (GNOME) |
| --------------- | ------------------ | --------------- |
| Area screenshot | `Print`            | `Ctrl+Print`    |
| Active window   | `Shift+Print`      | `Shift+Print`   |
| Full screen     | `Ctrl+Print`       | `Print`         |

> **Note:** Hyprland and GNOME bind `Print` and `Ctrl+Print` to opposite actions (`Shift+Print` = active window on both). GNOME's plain `Print` follows the GNOME default (full screen).

### Hyprland-Only

| Action                    | Binding         | Notes |
| ------------------------- | --------------- | ----- |
| Special workspace toggle  | `Super+U`       |       |
| Move to special workspace | `Super+Shift+U` |       |
| Scratchpad terminal       | `Super+Shift+T` |       |
| Volume control            | `Super+V`       |       |
| Interactive resize        | `Super+R`       |       |
| Mouse move window         | `Super+LMB`     |       |
| Mouse resize window       | `Super+RMB`     |       |

### GNOME-Only

| Action                       | Binding                      | Notes                                                                                        |
| ---------------------------- | ---------------------------- | -------------------------------------------------------------------------------------------- |
| Workspace left/right         | `Super+Alt+Left/Right`       |                                                                                              |
| Move to workspace left/right | `Super+Shift+Alt+Left/Right` |                                                                                              |
| First/last workspace         | `Super+Home/End`             |                                                                                              |
| Move to first/last workspace | `Super+Shift+Home/End`       |                                                                                              |
| Maximize / minimize          | `Super+Up/Down`              | Legacy; use `Super+M` instead                                                                |
| App switching                | `Super+Tab` / `Alt+Tab`      | `Alt+Tab` overlaps Ghostty's Alt namespace — no conflict because compositor intercepts first |
| Group switching              | `` Super+` `` / `` Alt+` ``  | Same as above                                                                                |
| Window menu                  | `Alt+Space`                  | Same as above                                                                                |
| Toggle maximize              | `Alt+F10`                    | Legacy; replaced by `Super+M`                                                                |
| Run dialog                   | `Alt+F2`                     | Compositor intercepts; `F2` not used in Ghostty Alt scheme                                   |

---

## Window Manager — macOS (AeroSpace)

### Window Management

| Action                   | Binding                 | Linux equivalent      |
| ------------------------ | ----------------------- | --------------------- |
| Focus left/down/up/right | `Alt+Cmd+H/J/K/L`       | `Super+H/J/K/L`       |
| Swap window              | `Alt+Cmd+Shift+H/J/K/L` | `Super+Shift+H/J/K/L` |
| Resize window            | `Ctrl+Cmd+Arrows`       | `Super+Alt+Arrows` (Hyprland) · `Super+Ctrl+Arrows` (GNOME) |
| Close window             | `Alt+Cmd+Q`             | `Super+Q`             |
| Fullscreen               | `Alt+Cmd+F`             | `Super+F`             |
| Toggle maximize          | `Alt+Cmd+M`             | `Super+M`             |

### Workspaces

| Action                  | Binding             | Linux equivalent  |
| ----------------------- | ------------------- | ----------------- |
| Switch to workspace 1-9 | `Alt+Cmd+1-9`       | `Super+1-9`       |
| Switch to workspace 10  | `Alt+Cmd+0`         | `Super+0`         |
| Move to workspace 1-9   | `Alt+Cmd+Shift+1-9` | `Super+Shift+1-9` |
| Move to workspace 10    | `Alt+Cmd+Shift+0`   | `Super+Shift+0`   |

### Monitor

| Action                   | Binding                     |
| ------------------------ | --------------------------- |
| Focus monitor left/right | `Ctrl+Cmd+Shift+Left/Right` |
| Move window to monitor   | `Ctrl+Cmd+Shift+H/L`        |

### Utilities

| Action                 | Binding     | Linux equivalent |
| ---------------------- | ----------- | ---------------- |
| App launcher (Raycast) | `Alt+Cmd+D` | `Super+D`        |

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

#### Navigate & Resize (`Alt`)

| Action                         | Binding        |
| ------------------------------ | -------------- |
| Focus split left/down/up/right | `Alt+H/J/K/L`  |
| Resize split                   | `Alt+Arrows`   |
| Switch to tab 1-8              | `Alt+1-8`      |
| Switch to last tab             | `Alt+9`        |
| Previous tab                   | `Alt+[`        |
| Next tab                       | `Alt+]`        |
| Jump to prompt prev            | `Alt+PageUp`   |
| Jump to prompt next            | `Alt+PageDown` |

#### Structure (`Alt+Shift`)

| Action                    | Binding        |
| ------------------------- | -------------- |
| New split right (logical) | `Alt+Shift+\|` |
| New split down (logical)  | `Alt+Shift+-`  |
| New tab                   | `Alt+Shift+T`  |
| Close tab                 | `Alt+Shift+Q`  |
| New window                | `Alt+Shift+W`  |
| Close window              | `Alt+Shift+X`  |

#### Zoom (`Alt+Ctrl`)

| Action            | Binding          |
| ----------------- | ---------------- |
| Toggle split zoom | `Alt+Ctrl+Enter` |

> `Alt+HJKL` focuses splits and `Alt+Arrows` resizes them, mirroring Neovim's
> `Ctrl+HJKL` / `Ctrl+Arrows`. This freed the whole `Alt+Ctrl+HJKL`/`Arrows`
> tier plus the redundant `Alt+Shift+HJKL`/`Arrows` split-creation aliases.
> Because Ghostty no longer grabs `Alt+Ctrl+HJKL`, that chord now passes
> through to Neovim as `Ctrl+Alt+HJKL` (used there for window relocation).

### Standard Bindings (Non-Alt)

Terminal-universal and OS-standard conventions — not part of the Alt scheme.

| Action                  | Binding        |
| ----------------------- | -------------- |
| Copy to clipboard       | `Ctrl+Shift+C` |
| Paste from clipboard    | `Ctrl+Shift+V` |
| Select all              | `Ctrl+Shift+A` |
| Paste from selection    | `Shift+Insert` |
| Copy to clipboard (alt) | `Ctrl+Insert`  |
| Quit app                | `Ctrl+Shift+Q` |
| Command palette         | `Ctrl+Shift+P` |
| Inspector               | `Ctrl+Shift+I` |

### Font & Display (`Alt`)

Font and fullscreen live on `Alt` (terminal-owned), keeping bare `Ctrl` free for Neovim. Config moves to the prefix (see Prefix Mode).

| Action             | Binding     |
| ------------------ | ----------- |
| Toggle fullscreen  | `Alt+Enter` |
| Increase font size | `Alt+=`     |
| Decrease font size | `Alt+-`     |
| Reset font size    | `Alt+0`     |

### Other Conventions

| Action               | Binding             |
| -------------------- | ------------------- |
| Scroll page up/down  | `Shift+PageUp/Down` |
| Scroll to top/bottom | `Shift+Home/End`    |
| Adjust selection     | `Shift+Arrows`      |

### Prefix Mode (`Ctrl+A`)

Prefix mode mirrors direct bindings and adds power-user commands.

| Binding            | Action                           |
| ------------------ | -------------------------------- |
| `Prefix > H/J/K/L` | Focus split                      |
| `Prefix > [/]`     | Focus prev/next split            |
| `Prefix > Arrows`  | Focus split                      |
| `Prefix > T > N`   | New tab                          |
| `Prefix > T > Q`   | Close tab                        |
| `Prefix > T > [/]` | Prev/next tab                    |
| `Prefix > W > N`   | New window                       |
| `Prefix > W > Q`   | Close window                     |
| `Prefix > C`       | Open config                      |
| `Prefix > R`       | Reload config                    |
| `Prefix > \|`      | New split right                  |
| `Prefix > -`       | New split down                   |
| `Prefix > S`       | Write screen to file (paste)     |
| `Prefix > Shift+S` | Write screen to file (open)      |
| `Prefix > Ctrl+S`  | Write screen to file (copy)      |
| `Prefix > B`       | Write scrollback to file (paste) |
| `Prefix > Shift+B` | Write scrollback to file (open)  |
| `Prefix > Ctrl+B`  | Write scrollback to file (copy)  |
| `Prefix > E`       | Write selection to file (paste)  |
| `Prefix > Shift+E` | Write selection to file (open)   |
| `Prefix > Ctrl+E`  | Write selection to file (copy)   |

---

## Editor (Neovim)

### Window Navigation (`Ctrl`)

| Action                   | Binding      | Modes            |
| ------------------------ | ------------ | ---------------- |
| Focus left window        | `Ctrl+H`       | Normal, Terminal |
| Focus down window        | `Ctrl+J`       | Normal, Terminal |
| Focus up window          | `Ctrl+K`       | Normal, Terminal |
| Focus right window       | `Ctrl+L`       | Normal, Terminal |
| Move window far left     | `Ctrl+Alt+H`   | Normal           |
| Move window to bottom    | `Ctrl+Alt+J`   | Normal           |
| Move window to top       | `Ctrl+Alt+K`   | Normal           |
| Move window far right    | `Ctrl+Alt+L`   | Normal           |
| Resize (decrease height) | `Ctrl+Up`      | Normal           |
| Resize (increase height) | `Ctrl+Down`    | Normal           |
| Resize (increase width)  | `Ctrl+Left`    | Normal           |
| Resize (decrease width)  | `Ctrl+Right`   | Normal           |

> **Note:** Resize uses Arrows because `Ctrl+HJKL` is navigate. Window
> relocation (`Ctrl+Alt+HJKL`, the Structure tier) became available once
> Ghostty stopped binding `Alt+Ctrl+HJKL` for split-resize — it now passes the
> chord through to Neovim. Requires the Kitty keyboard protocol (Ghostty and
> Neovim both support it).

### Line, Paragraph & File Navigation

| Action             | Primary        | Alternative | Vim native |
| ------------------ | -------------- | ----------- | ---------- |
| Line begin         | `H`            | `g[`        | `^` / `0`  |
| Line end           | `L`            | `g]`        | `$`        |
| Next paragraph     | `J`            | —           | `}`        |
| Previous paragraph | `K`            | —           | `{`        |
| File end           | `Ctrl+Shift+J` | —           | `G`        |
| File begin         | `Ctrl+Shift+K` | —           | `gg`       |

`H`, `L`, `J`, and `K` work in normal and visual mode. `g`-prefix bindings work in normal and visual mode.

#### Relocated defaults

| Action                 | New binding | Was |
| ---------------------- | ----------- | --- |
| Join lines             | `gJ`        | `J` |
| Keyword lookup / hover | `gh`        | `K` |

### Buffer Navigation

| Action                | Binding         |
| --------------------- | --------------- |
| Go to buffer 1-9      | `Leader+1-9`    |
| Next buffer           | `}` (`Shift+]`) |
| Previous buffer       | `{` (`Shift+[`) |
| Move buffer right     | `Ctrl+Shift+]`  |
| Move buffer left      | `Ctrl+Shift+[`  |
| Next buffer (alt)     | `]b`            |
| Previous buffer (alt) | `[b`            |
| Next diagnostic       | `]d`            |
| Previous diagnostic   | `[d`            |
| Next error            | `]e`            |
| Previous error        | `[e`            |
| Next warning          | `]w`            |
| Previous warning      | `[w`            |

### Buffer Management (`Leader+b`)

| Action              | Binding     | Notes        |
| ------------------- | ----------- | ------------ |
| Previous buffer     | `Leader+b[` | Mirrors `[b` |
| Next buffer         | `Leader+b]` | Mirrors `]b` |
| Close buffer        | `Leader+bq` |              |
| Toggle pin          | `Leader+bp` |              |
| Close buffers left  | `Leader+bl` |              |
| Close other buffers | `Leader+bo` |              |
| Close non-pinned    | `Leader+bP` |              |

### Window Management (`Leader+w`)

| Action                 | Binding      | Notes            |
| ---------------------- | ------------ | ---------------- |
| Focus left             | `Leader+wh`  | Mirrors `Ctrl+H` |
| Focus down             | `Leader+wj`  | Mirrors `Ctrl+J` |
| Focus up               | `Leader+wk`  | Mirrors `Ctrl+K` |
| Focus right            | `Leader+wl`  | Mirrors `Ctrl+L` |
| Previous window        | `Leader+wp`  |                  |
| Close window           | `Leader+wq`  |                  |
| Split right            | `Leader+w\|` | Also `Leader+\|` |
| Split below            | `Leader+w-`  | Also `Leader+-`  |
| Maximize (toggle zoom) | `Leader+wm`  |                  |
| Equalize sizes         | `Leader+w=`  |                  |

### Tab Management (`Leader+Tab`)

| Action           | Binding                       |
| ---------------- | ----------------------------- |
| New tab (fast)   | `Ctrl+T` (twin of `Leader+Tab+n`; shadows tag-pop, use `Ctrl+O`) |
| Next tab (fast)  | `gt` (vim-native; `gT` is remapped to LSP type-definition) |
| Last tab         | `Leader+Tab+l`                |
| First tab        | `Leader+Tab+f`                |
| New tab          | `Leader+Tab+n`                |
| Next tab         | `Leader+Tab+]`                |
| Close tab        | `Leader+Tab+q`                |
| Previous tab     | `Leader+Tab+[`                |

Fast tab chords can't mirror Ghostty's `Alt+[`/`Alt+]`: `Ctrl+[`/`Ctrl+]` are
remapped to the jumplist (back/forward), and `gT` is remapped to LSP
type-definition. So the only fast tab keys are `gt` (next) and `Ctrl+T` (new);
previous-tab stays on `Leader+Tab+[`.

### Line Move

| Action         | Binding        | Modes                  |
| -------------- | -------------- | ---------------------- |
| Move line up   | `Ctrl+Shift+<` | Normal, Insert, Visual |
| Move line down | `Ctrl+Shift+>` | Normal, Insert, Visual |

> **Note:** Uses `Ctrl+Shift+</>` — `<`/`>` have a shift/move connotation and are unbound in Ghostty's `Ctrl+Shift` namespace. Replaces `Alt+J/K` which conflicts with Ghostty split navigation.

### General

| Action                       | Binding     | Modes                                |
| ---------------------------- | ----------- | ------------------------------------ |
| Save file                    | `Ctrl+S`    | All                                  |
| Clear search                 | `Esc`       | Normal, Insert                       |
| Redraw / clear hlsearch      | `Leader+ur` | Normal                               |
| Line diagnostics             | `Leader+cd` | Normal                               |
| Inspect position             | `Leader+ui` | Normal                               |
| Enter normal mode (terminal) | `Esc Esc`   | Terminal                             |
| Quit all                     | `Leader+qq` | Normal                               |
| Jump back                    | `Ctrl+[`    | Normal — remapped from Esc; see note |
| Jump forward                 | `Ctrl+]`    | Normal                               |

> **Note:** `Ctrl+[` is the ANSI equivalent of `Esc`. Remapping it to "jump back" in normal mode overrides the default Escape behavior. This is intentional — `Esc` is mapped separately for clearing search highlights.

### Search

| Action                 | Binding | Modes                    |
| ---------------------- | ------- | ------------------------ |
| Next search result     | `n`     | Normal, Visual, Operator |
| Previous search result | `N`     | Normal, Visual, Operator |
