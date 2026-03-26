# AeroSpace Tiling WM for macOS

## Goal

Add tiling window manager support to macOS using AeroSpace, with keybindings aligned to the unified Hyprland/GNOME scheme. Muscle memory for spatial navigation (hjkl), workspaces (1-9,0), and window operations (close, fullscreen, swap, resize) should transfer from Linux to macOS.

## Constraints

- Ghostty terminal and Neovim keybindings are fixed — the desktop layer must not conflict with them.
- macOS `Cmd` is heavily used by the OS and apps (`Cmd+C/V/Q/W/Tab`, etc.), so `Cmd` alone cannot serve as the primary WM modifier.
- AeroSpace intercepts keys system-wide before they reach apps.

## Approach

Use a different modifier prefix on macOS than Linux. The spatial layout (hjkl for directions, 1-9,0 for workspaces) stays consistent, but the modifier keys differ to avoid conflicts with macOS system shortcuts and the terminal/editor layers.

## Modifier Mapping

`Alt+Cmd` (Option+Cmd) replaces Linux `Super` as the primary desktop modifier. This sits entirely outside the existing modifier hierarchy — no layer uses `Cmd`.

| Layer | Linux | macOS | Purpose |
|---|---|---|---|
| Primary | `Super+key` | `Alt+Cmd+key` | Focus, workspaces, launch, close, fullscreen |
| Move/Transfer | `Super+Shift+key` | `Alt+Cmd+Shift+key` | Swap windows, move to workspace |
| Resize | `Super+Alt+key` | `Ctrl+Cmd+key` | Resize windows |
| Monitor | `Super+Ctrl+key` | `Ctrl+Cmd+Shift+key` | Focus monitor, move to monitor |

Note: On Linux, all four layers build on `Super` by adding one modifier (`Shift`, `Alt`, `Ctrl`). On macOS, the mapping is less symmetric — Primary and Move/Transfer share the `Alt+Cmd` base, while Resize and Monitor share the `Ctrl+Cmd` base. This is a deliberate trade-off to keep each layer conflict-free within macOS's modifier space.

### Overridden macOS System Defaults

AeroSpace intercepts keys before they reach the OS, so these macOS defaults are intentionally overridden:

| macOS Default | Default Action | Our Binding |
|---|---|---|
| `Alt+Cmd+H` | Hide Other Windows | Focus left |
| `Alt+Cmd+D` | Toggle Dock Auto-Hide | App launcher (Raycast) |

When AeroSpace is disabled or not running, these keys revert to macOS defaults.

### Close Window vs Quit App

`Alt+Cmd+Q` closes the focused window via AeroSpace. `Cmd+Q` remains the standard macOS quit-app shortcut. Both are available — a useful distinction between closing a single window and quitting the entire app.

Preserved layers (no conflicts):

| Modifier | Layer |
|---|---|
| `Ctrl+key` | Editor (Neovim) |
| `Alt+key` | Editor (Neovim) |
| `Alt+Shift+key` | Terminal (Ghostty) — split navigation |
| `Ctrl+Shift+key` | Terminal (Ghostty) — split creation, copy/paste |
| `Alt+Ctrl+key` | Terminal (Ghostty) — tab management |
| `Alt+Shift+Ctrl+key` | Terminal (Ghostty) — split resize |

## Keybindings

### Window Management

| Action | macOS Binding | Linux Equivalent |
|---|---|---|
| Focus left/down/up/right | `Alt+Cmd+h/j/k/l` | `Super+h/j/k/l` |
| Swap window left/down/up/right | `Alt+Cmd+Shift+h/j/k/l` | `Super+Shift+h/j/k/l` |
| Resize left/down/up/right | `Ctrl+Cmd+h/j/k/l` | `Super+Alt+h/j/k/l` |
| Close window | `Alt+Cmd+q` | `Super+Q` |
| Fullscreen | `Alt+Cmd+f` | `Super+F` |

AeroSpace resize uses `resize width/height +/-N` commands. Increment of 50px per keypress (adjustable). Direction mapping:

- `h` (left): `resize width -50`
- `l` (right): `resize width +50`
- `k` (up): `resize height +50`
- `j` (down): `resize height -50`

### Workspaces

| Action | macOS Binding | Linux Equivalent |
|---|---|---|
| Switch to workspace 1-9 | `Alt+Cmd+1-9` | `Super+1-9` |
| Switch to workspace 10 | `Alt+Cmd+0` | `Super+0` |
| Move window to workspace 1-9 | `Alt+Cmd+Shift+1-9` | `Super+Shift+1-9` |
| Move window to workspace 10 | `Alt+Cmd+Shift+0` | `Super+Shift+0` |

### Monitor Focus & Move

| Action | macOS Binding |
|---|---|
| Focus next monitor | `Ctrl+Cmd+Shift+right` |
| Focus prev monitor | `Ctrl+Cmd+Shift+left` |
| Move window to next monitor | `Ctrl+Cmd+Shift+l` |
| Move window to prev monitor | `Ctrl+Cmd+Shift+h` |

Arrow keys for focus, hjkl for move — no collision since they are distinct keys.

### App Launcher

| Action | macOS Binding | Linux Equivalent |
|---|---|---|
| App launcher (Raycast) | `Alt+Cmd+d` | `Super+D` |

Triggered via AeroSpace `exec-and-forget` or configured directly in Raycast.

### Bindings NOT Carried Over

These Linux bindings are handled natively by macOS and not included in AeroSpace config:

- `Super+T` / `Ctrl+Alt+T` (open terminal) — use Raycast or macOS native
- `Super+Space` (keyboard layout) — macOS input source switcher
- `Super+Backspace` (lock) — macOS native `Ctrl+Cmd+Q`
- Screenshots — macOS native `Cmd+Shift+3/4/5`
- Special workspace / scratchpad — no AeroSpace equivalent
- Media/brightness keys — macOS native

## Module Structure

Follows the Hyprland pattern: darwin module for system-level installation, home-manager module for user-level configuration.

```
modules/darwin/desktops/aerospace/
  default.nix          # Option definition, Homebrew tap + cask installation

modules/home/desktops/aerospace/
  default.nix          # Module definition, AeroSpace TOML config generation
  keybindings.nix      # Keybinding definitions
```

### Darwin Module (`modules/darwin/desktops/aerospace/default.nix`)

- Declares `nix-config.desktops.aerospace.enable` option
- When enabled, adds `"nikitabobko/tap/aerospace"` to `${namespace}.system.homebrew.casks` (Homebrew auto-taps from the full cask path — no explicit `taps` entry needed, avoiding changes to the homebrew wrapper module)

### Home-Manager Module (`modules/home/desktops/aerospace/default.nix`)

- Declares `nix-config.desktops.aerospace.enable` option
- Imports `keybindings.nix`
- Generates `~/.aerospace.toml` via `home.file.".aerospace.toml".text` using a raw TOML multiline string in Nix (not `lib.generators.toTOML` — AeroSpace TOML is simple enough that a template string is more readable and maintainable)

### Home-Manager Keybindings (`modules/home/desktops/aerospace/keybindings.nix`)

- Exports a Nix attribute set or string fragment that `default.nix` interpolates into the TOML config
- Separated from main config for clarity (parallel to `hyprland/keybindings.nix` and `gnome/keybindings.nix`)

## AeroSpace Configuration

General settings for `~/.aerospace.toml`:

- `start-at-login = true`
- `enable-normalization-flatten-containers = true`
- `enable-normalization-opposite-orientation-for-nested-containers = true`
- `accordion-padding = 30`
- `default-root-container-layout = 'tiles'`
- `default-root-container-orientation = 'auto'`

Gaps (consistent with Hyprland `gaps_in = 5, gaps_out = 10`):

- `inner.horizontal = 10`
- `inner.vertical = 10`
- `outer.left/right/top/bottom = 10`

Single mode (`[mode.main.binding]`) — no modal keybindings.

## Integration Changes

### Darwin Work Role (`modules/darwin/roles/work/default.nix`)

- Remove `"rectangle"` from Homebrew casks
- Add `desktops.aerospace = enabled;`

### Home-Manager Work Role (`modules/home/roles/work/default.nix`)

- Add `desktops.aerospace = enabled;`

### Files to Create

- `modules/darwin/desktops/aerospace/default.nix`
- `modules/home/desktops/aerospace/default.nix`
- `modules/home/desktops/aerospace/keybindings.nix`

### Files to Modify

- `modules/darwin/roles/work/default.nix` — remove Rectangle, enable AeroSpace
- `modules/home/roles/work/default.nix` — enable AeroSpace home-manager module
