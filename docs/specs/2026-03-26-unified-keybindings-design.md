# Unified Keybinding Scheme: Hyprland + GNOME

## Goal

Align keybindings between Hyprland and GNOME desktop environments so that muscle memory transfers between them. Ghostty terminal and Neovim editor keybindings are treated as fixed constraints — the desktop layer must not conflict with them.

## Approach

Independent alignment (Approach B): update each DE's keybinding config separately to follow the same scheme. No shared abstraction layer. DE-specific actions remain in their respective configs.

## Modifier Key Hierarchy

The desktop layer uses `Super` exclusively, which never reaches terminal or editor.

| Modifier | Layer | Purpose |
|---|---|---|
| `Ctrl+key` | Editor (Neovim) | Window nav, save, resize |
| `Alt+key` | Editor (Neovim) | Line movement, line nav |
| `Alt+Shift+key` | Terminal (Ghostty) | Split navigation |
| `Ctrl+Shift+key` | Terminal (Ghostty) | Split creation, copy/paste |
| `Alt+Ctrl+key` | Terminal (Ghostty) | Tab management |
| `Alt+Shift+Ctrl+key` | Terminal (Ghostty) | Split resize |
| `Super+key` | Desktop — primary | Focus, workspaces, launch apps |
| `Super+Shift+key` | Desktop — move/transfer | Move windows, move to workspace |
| `Super+Ctrl+key` | Desktop — monitor | Move workspace to monitor, focus monitor |
| `Super+Alt+key` | Desktop — resize/layout | Resize windows |

## Unified Bindings (both DEs)

### Window Management

| Action | Binding | Notes |
|---|---|---|
| Focus left/down/up/right | `Super+h/j/k/l` | Forge in GNOME |
| Swap window left/down/up/right | `Super+Shift+h/j/k/l` | Forge swap in GNOME |
| Resize window left/down/up/right | `Super+Alt+h/j/k/l` | Forge resize in GNOME, `binde` in Hyprland |
| Close window | `Super+Q` and `Alt+F4` | `Alt+F4` new for Hyprland; Ghostty also binds `alt+f4=quit` so it closes terminal when focused (expected) |
| Fullscreen | `Super+F` | |

### Workspaces

| Action | Binding |
|---|---|
| Switch to workspace 1-9 | `Super+1-9` |
| Switch to workspace 10 | `Super+0` |
| Move window to workspace 1-9 | `Super+Shift+1-9` |
| Move window to workspace 10 | `Super+Shift+0` |

GNOME requires static workspaces. Dconf keys:
- `org/gnome/mutter` → `dynamic-workspaces = false`
- `org/gnome/desktop/wm/preferences` → `num-workspaces = 10`

### App Launchers & Utilities

| Action | Binding | Notes |
|---|---|---|
| Open terminal | `Super+T` and `Ctrl+Alt+T` | `Ctrl+Alt+T` passes through Ghostty since `alt+ctrl+t` is not bound there (Ghostty clears defaults) |
| App launcher/search | `Super+D` | Rofi in Hyprland, search-light in GNOME |
| Switch keyboard layout | `Super+Space` | |
| Switch keyboard layout back | `Super+Shift+Space` | |
| Lock screen | `Super+Backspace` | hyprlock / GNOME screensaver |
| Power/logout menu | `Ctrl+Super+Backspace` | wlogout / GNOME power-off |

### Screenshots

| Action | Binding |
|---|---|
| Screenshot area | `Print` |
| Screenshot active window | `Shift+Print` |
| Screenshot full screen | `Ctrl+Print` |

Hyprland: all screenshots use `grimblast --notify copysave` for consistency (copy to clipboard + save to file).
GNOME: uses native `gnome-screenshot` or equivalent.

## Hyprland-Only Bindings

| Action | Binding | Notes |
|---|---|---|
| Move window (directional) | `Alt+Ctrl+h/j/k/l` | Exception to hierarchy: `Alt+Ctrl` is nominally Ghostty's layer, but Ghostty only uses `n`, `q`, `1-9` on this modifier — no conflict with `h/j/k/l` |
| Move workspace to monitor | `Super+Ctrl+h/j/k/l` | Changed from `Super+Alt` to resolve double-bind conflict |
| Focus monitor | `Super+Ctrl+Arrow` | Changed from `Super+Ctrl+hjkl` to make room for workspace-to-monitor |
| Special workspace toggle | `Super+U` | |
| Move to special workspace | `Super+Shift+U` | |
| Scratchpad terminal | `Super+Shift+T` | pyprland toggle |
| Volume control | `Super+V` | pyprland toggle pwvucontrol |
| Interactive resize (slurp) | `Super+R` | |
| Lock (hardware keys) | `XF86Launch4`, `XF86Launch5` | |
| Mouse move window | `Super+LMB` | |
| Mouse resize window | `Super+RMB` | |
| Lid switch | Hardware switch | |
| Media/brightness keys | `XF86*` | DE-native |

## GNOME-Only Bindings

| Action | Binding | Notes |
|---|---|---|
| Workspace left/right (sequential) | `Super+Alt+Left/Right` | Uses `Super+Alt+Arrow`, not `hjkl` — no conflict with resize which uses `hjkl` only |
| Move window to workspace left/right | `Super+Shift+Alt+Left/Right` | |
| Switch to first/last workspace | `Super+Home` / `Super+End` | |
| Move to first/last workspace | `Super+Shift+Home` / `Super+Shift+End` | |
| Move to monitor (directional) | `Super+Shift+Arrow` | |
| Activate window menu | `Alt+Space` | |
| Toggle maximize | `Alt+F10` | |
| Maximize | `Super+Up` | |
| Minimize | `Super+Down` | |
| App switching | `Super+Tab` / `Alt+Tab` | |
| Group switching | `` Super+` `` / `` Alt+` `` | |
| Run dialog | `Alt+F2` | |

Note: `Ctrl+Alt+Tab` (switch-panels) is removed — `Ctrl+Alt` modifier belongs to Ghostty's tab layer.

## Forge Dconf Configuration (GNOME)

Forge keybindings must be configured via dconf at `org/gnome/shell/extensions/forge/keybindings`:

| Action | Dconf key | Value |
|---|---|---|
| Focus left | `focus-left` | `<Super>h` |
| Focus right | `focus-right` | `<Super>l` |
| Focus up | `focus-up` | `<Super>k` |
| Focus down | `focus-down` | `<Super>j` |
| Swap left | `swap-left` | `<Super><Shift>h` |
| Swap right | `swap-right` | `<Super><Shift>l` |
| Swap up | `swap-up` | `<Super><Shift>k` |
| Swap down | `swap-down` | `<Super><Shift>j` |
| Resize left | `con-resize-left` | `<Super><Alt>h` |
| Resize right | `con-resize-right` | `<Super><Alt>l` |
| Resize up | `con-resize-up` | `<Super><Alt>k` |
| Resize down | `con-resize-down` | `<Super><Alt>j` |

Clear any Forge defaults that conflict with the unified scheme (e.g., default `Super+hjkl` may already be correct, but verify).

## Changes From Current Config

### Hyprland

| Change | Detail |
|---|---|
| Remove | `Super+B` (was rofi launcher) |
| Remove | `Super+Print` (window copy-only) |
| Remove | `Alt+Print` (area copy-only) |
| Remove | `Super+bracketleft/right` (screenshot with cursor) |
| Add | `Super+D` — app launcher (rofi) |
| Add | `Alt+F4` — close window (alongside existing `Super+Q`) |
| Change | `Super+Alt+h/j/k/l` — now resize only (was also move-workspace-to-monitor) |
| Change | `Super+Ctrl+h/j/k/l` — now move-workspace-to-monitor (was focus-monitor) |
| Add | `Super+Ctrl+Arrow` — focus monitor (replaces `Super+Ctrl+hjkl`) |

### GNOME

| Change | Detail |
|---|---|
| Remove | `Super+B` (was search-light) |
| Remove | `Super+W` / `Ctrl+Alt+W` (was browser) |
| Remove | `Ctrl+Alt+Left/Right` (workspace switch — conflicts with Ghostty `Alt+Ctrl` layer) |
| Remove | `Super+Page_Up/Down` (redundant with `Super+Alt+Arrow`) |
| Remove | `Super+Shift+Page_Up/Down` (redundant with `Super+Shift+Alt+Arrow`) |
| Remove | `Ctrl+Alt+Tab` / `Shift+Ctrl+Alt+Tab` (switch-panels/backward — conflicts with Ghostty `Alt+Ctrl` layer) |
| Add | `Super+D` — search-light launcher |
| Add | `Super+Q` — close window (alongside existing `Alt+F4`) |
| Add | `Super+F` — fullscreen |
| Add | `Super+1-9,0` — direct workspace switching |
| Add | `Super+Shift+1-9,0` — move window to workspace |
| Add | `Super+Backspace` — lock screen |
| Add | `Ctrl+Super+Backspace` — power/logout |
| Add | `Print` / `Shift+Print` / `Ctrl+Print` — unified screenshot bindings |
| Add | Static workspaces = 10 (`dynamic-workspaces = false`, `num-workspaces = 10`) |
| Add | Forge dconf keybindings for `Super+hjkl` focus, `Super+Shift+hjkl` swap, `Super+Alt+hjkl` resize |
| Cleanup | Consolidate terminal binding — use `open-terminal` dconf key only, remove redundant `custom0`/`custom1` entries |
| Preserve | `Alt+F4` close, `Alt+F5` unmaximize, `Alt+F6` cycle-group, `Alt+Space` window menu, `Alt+F10` toggle maximize, `Alt+Escape`/`Shift+Alt+Escape` cycle-windows, `Super+Up/Down` maximize/minimize, `Super+Tab`/`Alt+Tab` app switching, `Alt+F2` run dialog, `Super+Home/End` first/last workspace |

## Files to Modify

- `modules/home/desktops/hyprland/keybindings.nix` — update bind arrays
- `modules/home/desktops/gnome/keybindings.nix` — update dconf keybindings, add Forge dconf, add static workspaces, add screenshot/lock/power bindings
