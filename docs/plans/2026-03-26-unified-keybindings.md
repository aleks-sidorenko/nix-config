# Unified Keybindings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align keybindings between Hyprland and GNOME so muscle memory transfers, without conflicting with Ghostty or Neovim.

**Architecture:** Two independent file edits — Hyprland `keybindings.nix` and GNOME `keybindings.nix`. No shared abstraction. Each file is updated to follow the unified scheme from the spec at `docs/specs/2026-03-26-unified-keybindings-design.md`.

**Tech Stack:** Nix (home-manager modules, dconf settings)

---

### Task 1: Update Hyprland keybindings

**Files:**
- Modify: `modules/home/desktops/hyprland/keybindings.nix`

**Spec reference:** `docs/specs/2026-03-26-unified-keybindings-design.md` — sections "Unified Bindings", "Hyprland-Only Bindings", "Changes From Current Config > Hyprland"

- [ ] **Step 1: Update the `bind` array**

In `modules/home/desktops/hyprland/keybindings.nix`, replace the `bind` array (lines 67-133) with the following. Changes from current:
- `SUPER, B` line removed (was rofi launcher)
- `SUPER, D` added (new rofi launcher)
- `ALT, F4` added (close window)
- `SUPERCONTROL,h/l/k/j` changed from `focusmonitor` to `movecurrentworkspacetomonitor`
- `SUPERALT,h/l/k/j` for `movecurrentworkspacetomonitor` removed from `bind` (moved to `SUPERCONTROL`; resize in `binde` is unchanged)
- `SUPER,bracketleft` and `SUPER,bracketright` removed (screenshot shortcuts)
- `SHIFT, Print` changed to `copysave` for consistency
- `CONTROL,Print` changed to `copysave` for consistency
- `SUPER,Print` removed (was window copy-only)
- `ALT,Print` removed (was area copy-only)
- `SUPERCONTROL,Left/Right/Up/Down` added (focus monitor via arrows)

Replace the full `bind` array with:

```nix
bind = [
  "SUPER, T, exec, ${terminal}"
  "ALTCTRL, T, exec, ${terminal}"
  "SUPER, D, exec, ${
    lib.getExe config.${namespace}.desktops.addons.rofi.package
  } -show drun -mode drun"
  "SUPER, Q, killactive,"
  "ALT, F4, killactive,"
  "SUPER, F, Fullscreen,0"
  "SUPER, R, exec, ${lib.getExe resize}"
  "SUPER, Space, keyboardlayoutnext,"
  "SUPER, V, exec, ${lib.getExe pkgs.pyprland} toggle pwvucontrol"
  "SUPER_SHIFT, T, exec, ${lib.getExe pkgs.pyprland} toggle term"
  "SUPER_SHIFT, Space, keyboardlayoutprev,"
  ",XF86Launch5, exec, ${lib.getExe pkgs.hyprlock}"
  ",XF86Launch4, exec, ${lib.getExe pkgs.hyprlock}"
  "SUPER,backspace, exec, ${lib.getExe pkgs.hyprlock}"
  "CTRL_SUPER,backspace, exec,wlogout --column-spacing 50 --row-spacing 50"
  ", Print, exec, grimblast --notify copysave area"
  "SHIFT, Print, exec, grimblast --notify copysave active"
  "CONTROL, Print, exec, grimblast --notify copysave screen"
  "SUPER,h, movefocus,l"
  "SUPER,l, movefocus,r"
  "SUPER,k, movefocus,u"
  "SUPER,j, movefocus,d"
  "SUPERCONTROL,h, movecurrentworkspacetomonitor,l"
  "SUPERCONTROL,l, movecurrentworkspacetomonitor,r"
  "SUPERCONTROL,k, movecurrentworkspacetomonitor,u"
  "SUPERCONTROL,j, movecurrentworkspacetomonitor,d"
  "SUPERCONTROL,Left, focusmonitor,l"
  "SUPERCONTROL,Right, focusmonitor,r"
  "SUPERCONTROL,Up, focusmonitor,u"
  "SUPERCONTROL,Down, focusmonitor,d"
  "SUPER,1, workspace,01"
  "SUPER,2, workspace,02"
  "SUPER,3, workspace,03"
  "SUPER,4, workspace,04"
  "SUPER,5, workspace,05"
  "SUPER,6, workspace,06"
  "SUPER,7, workspace,07"
  "SUPER,8, workspace,08"
  "SUPER,9, workspace,09"
  "SUPER,0, workspace,10"
  "SUPERSHIFT,1, movetoworkspacesilent,01"
  "SUPERSHIFT,2, movetoworkspacesilent,02"
  "SUPERSHIFT,3, movetoworkspacesilent,03"
  "SUPERSHIFT,4, movetoworkspacesilent,04"
  "SUPERSHIFT,5, movetoworkspacesilent,05"
  "SUPERSHIFT,6, movetoworkspacesilent,06"
  "SUPERSHIFT,7, movetoworkspacesilent,07"
  "SUPERSHIFT,8, movetoworkspacesilent,08"
  "SUPERSHIFT,9, movetoworkspacesilent,09"
  "SUPERSHIFT,0, movetoworkspacesilent,10"
  "ALTCTRL,L, movewindow,r"
  "ALTCTRL,H, movewindow,l"
  "ALTCTRL,K, movewindow,u"
  "ALTCTRL,J, movewindow,d"
  "SUPERSHIFT,h, swapwindow,l"
  "SUPERSHIFT,l, swapwindow,r"
  "SUPERSHIFT,k, swapwindow,u"
  "SUPERSHIFT,j, swapwindow,d"
  "SUPER,u, togglespecialworkspace"
  "SUPERSHIFT,u, movetoworkspace,special"
];
```

- [ ] **Step 2: Verify `binde`, `bindi`, `bindl`, `bindm` arrays unchanged**

The following arrays should remain exactly as they are in the current file:
- `bindi` (lines 134-145): media/brightness keys — no changes
- `bindl` (lines 146-148): lid switch — no changes
- `bindm` (lines 155-158): mouse bindings — no changes

The `binde` array (lines 149-154) stays as-is — it already has `SUPERALT,h/j/k/l` for `resizeactive` which is correct per the spec.

- [ ] **Step 3: Validate Hyprland config builds**

Run:
```bash
nix flake check 2>&1 | tail -20
```

Expected: no Nix evaluation errors.

- [ ] **Step 4: Commit**

```bash
git add modules/home/desktops/hyprland/keybindings.nix
git commit -m "feat(hyprland): align keybindings with unified scheme

- Replace Super+B with Super+D for app launcher
- Add Alt+F4 for close window
- Move focus-monitor from Super+Ctrl+hjkl to Super+Ctrl+Arrow
- Move workspace-to-monitor to Super+Ctrl+hjkl
- Remove Super+Alt+hjkl from bind (keep in binde for resize only)
- Simplify screenshots to 3 bindings with copysave
- Remove Super+bracketleft/right screenshot shortcuts"
```

---

### Task 2: Update GNOME keybindings

**Files:**
- Modify: `modules/home/desktops/gnome/keybindings.nix`

**Spec reference:** `docs/specs/2026-03-26-unified-keybindings-design.md` — sections "Unified Bindings", "GNOME-Only Bindings", "Forge Dconf Configuration", "Changes From Current Config > GNOME"

- [ ] **Step 1: Replace the full keybindings.nix file**

Replace the entire content of `modules/home/desktops/gnome/keybindings.nix` with the following. Key changes from current:

- Terminal binding consolidated (remove custom0/custom1, keep `open-terminal` only)
- `Super+B` (search-light) removed
- `Super+W` / `Ctrl+Alt+W` (browser) removed
- `Super+D` added for search-light
- `Super+Q` added for close
- `Super+F` added for fullscreen
- `Ctrl+Alt+Left/Right` removed from workspace switching
- `Super+Page_Up/Down` and `Super+Shift+Page_Up/Down` removed
- `Ctrl+Alt+Tab` / `Shift+Ctrl+Alt+Tab` removed
- `Super+1-9,0` workspace switching added
- `Super+Shift+1-9,0` move-to-workspace added
- `Super+Backspace` lock screen added
- `Ctrl+Super+Backspace` power menu added
- Screenshot bindings added (under `media-keys` for GNOME compatibility)
- Static workspaces enabled (10)
- Forge keybindings configured via dconf
- Fixed `begn-resize` typo to `begin-resize`
- Fixed `toggle-application-view` dconf path (was nested incorrectly as a sub-path)
- Replaced `"@as" = []` with `lib.gvariant.mkEmptyArray lib.gvariant.type.string` for type safety

```nix
{
  config,
  lib,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.desktops.gnome;
  terminal = lib.getExe config.${namespace}.cli.terminals.default.package;
in
{
  config = mkIf cfg.enable {
    dconf.settings = {
      # Terminal
      "org/gnome/desktop/applications/terminal" = {
        exec = terminal;
      };

      # Shell keybindings (terminal, app view)
      "org/gnome/shell/keybindings" = {
        open-terminal = [
          "<Super>t"
          "<Ctrl><Alt>t"
        ];
        toggle-application-view = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
      };

      # Media keys, screenshots, lock, power menu
      "org/gnome/settings-daemon/plugins/media-keys" = {
        www = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        screensaver = [ "<Super>BackSpace" ];
        logout = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        screenshot = [ "Print" ];
        window-screenshot = [ "<Shift>Print" ];
        area-screenshot = [ "<Ctrl>Print" ];
        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        ];
      };

      # Power menu via custom keybinding
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
        name = "Power Menu";
        command = "gnome-session-quit --power-off";
        binding = "<Ctrl><Super>BackSpace";
      };

      # Search light — new binding
      "org/gnome/shell/extensions/search-light" = {
        shortcut-search = [ "<Super>d" ];
      };

      # Window management
      "org/gnome/desktop/wm/keybindings" = {
        activate-window-menu = [ "<Alt>space" ];
        close = [
          "<Super>q"
          "<Alt>F4"
        ];
        toggle-fullscreen = [ "<Super>f" ];
        always-on-top = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        begin-move = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        begin-resize = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        cycle-group = [ "<Alt>F6" ];
        cycle-group-backward = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        cycle-panels = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        cycle-panels-backward = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        cycle-windows = [ "<Alt>Escape" ];
        cycle-windows-backward = [ "<Shift><Alt>Escape" ];
        lower = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        maximize = [ "<Super>Up" ];
        maximize-horizontally = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        maximize-vertically = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        minimize = [ "<Super>Down" ];
        move-to-monitor-down = [ "<Super><Shift>Down" ];
        move-to-monitor-left = [ "<Super><Shift>Left" ];
        move-to-monitor-right = [ "<Super><Shift>Right" ];
        move-to-monitor-up = [ "<Super><Shift>Up" ];
        move-to-workspace-1 = [
          "<Super><Shift>1"
          "<Super><Shift>Home"
        ];
        move-to-workspace-2 = [ "<Super><Shift>2" ];
        move-to-workspace-3 = [ "<Super><Shift>3" ];
        move-to-workspace-4 = [ "<Super><Shift>4" ];
        move-to-workspace-5 = [ "<Super><Shift>5" ];
        move-to-workspace-6 = [ "<Super><Shift>6" ];
        move-to-workspace-7 = [ "<Super><Shift>7" ];
        move-to-workspace-8 = [ "<Super><Shift>8" ];
        move-to-workspace-9 = [ "<Super><Shift>9" ];
        move-to-workspace-10 = [ "<Super><Shift>0" ];
        move-to-workspace-down = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        move-to-workspace-last = [ "<Super><Shift>End" ];
        move-to-workspace-left = [ "<Super><Shift><Alt>Left" ];
        move-to-workspace-right = [ "<Super><Shift><Alt>Right" ];
        move-to-workspace-up = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        panel-run-dialog = [ "<Alt>F2" ];
        switch-applications = [
          "<Super>Tab"
          "<Alt>Tab"
        ];
        switch-applications-backward = [
          "<Shift><Super>Tab"
          "<Shift><Alt>Tab"
        ];
        switch-group = [
          "<Super>Above_Tab"
          "<Alt>Above_Tab"
        ];
        switch-group-backward = [
          "<Shift><Super>Above_Tab"
          "<Shift><Alt>Above_Tab"
        ];
        switch-input-source = [ "<Super>space" ];
        switch-input-source-backward = [ "<Shift><Super>space" ];
        switch-panels = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        switch-panels-backward = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        switch-to-workspace-1 = [
          "<Super>1"
          "<Super>Home"
        ];
        switch-to-workspace-2 = [ "<Super>2" ];
        switch-to-workspace-3 = [ "<Super>3" ];
        switch-to-workspace-4 = [ "<Super>4" ];
        switch-to-workspace-5 = [ "<Super>5" ];
        switch-to-workspace-6 = [ "<Super>6" ];
        switch-to-workspace-7 = [ "<Super>7" ];
        switch-to-workspace-8 = [ "<Super>8" ];
        switch-to-workspace-9 = [ "<Super>9" ];
        switch-to-workspace-10 = [
          "<Super>0"
          "<Super>End"
        ];
        switch-to-workspace-down = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        switch-to-workspace-left = [ "<Super><Alt>Left" ];
        switch-to-workspace-right = [ "<Super><Alt>Right" ];
        switch-to-workspace-up = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        toggle-maximized = [ "<Alt>F10" ];
        unmaximize = [ "<Alt>F5" ];
      };

      # Static workspaces
      "org/gnome/mutter" = {
        dynamic-workspaces = false;
      };

      "org/gnome/desktop/wm/preferences" = {
        num-workspaces = 10;
      };

      # Forge tiling keybindings
      "org/gnome/shell/extensions/forge/keybindings" = {
        focus-left = [ "<Super>h" ];
        focus-right = [ "<Super>l" ];
        focus-up = [ "<Super>k" ];
        focus-down = [ "<Super>j" ];
        swap-left = [ "<Super><Shift>h" ];
        swap-right = [ "<Super><Shift>l" ];
        swap-up = [ "<Super><Shift>k" ];
        swap-down = [ "<Super><Shift>j" ];
        con-resize-left = [ "<Super><Alt>h" ];
        con-resize-right = [ "<Super><Alt>l" ];
        con-resize-up = [ "<Super><Alt>k" ];
        con-resize-down = [ "<Super><Alt>j" ];
      };
    };
  };
}
```

**Notes for the implementer:**
- The `"org/gnome/mutter"` settings here merge automatically with `monitors.nix` (which sets `experimental-features`) via home-manager's attrset merging.
- Verify Forge dconf key names by checking `dconf list /org/gnome/shell/extensions/forge/keybindings/` on a running GNOME session with Forge installed. The key names above are from Forge's documented schema and may need adjustment.

- [ ] **Step 2: Validate GNOME config builds**

Run:
```bash
nix flake check 2>&1 | tail -20
```

Expected: no Nix evaluation errors.

- [ ] **Step 3: Commit**

```bash
git add modules/home/desktops/gnome/keybindings.nix
git commit -m "feat(gnome): align keybindings with unified scheme

- Replace Super+B with Super+D for search-light
- Remove Super+W/Ctrl+Alt+W browser shortcut
- Add Super+Q and Super+F for close/fullscreen
- Add Super+1-9,0 for direct workspace switching
- Add Super+Shift+1-9,0 for move-to-workspace
- Enable static workspaces (10)
- Add Super+Backspace lock, Ctrl+Super+Backspace power menu
- Add Print/Shift+Print/Ctrl+Print screenshot bindings
- Configure Forge dconf for Super+hjkl focus/swap/resize
- Remove Ctrl+Alt bindings (conflicts with Ghostty)
- Consolidate terminal binding (remove custom keybinding duplication)
- Fix begn-resize typo"
```

---

### Task 3: Final validation

**Files:**
- Read: `modules/home/desktops/hyprland/keybindings.nix`
- Read: `modules/home/desktops/gnome/keybindings.nix`

- [ ] **Step 1: Run full flake check**

```bash
nix flake check 2>&1 | tail -30
```

Expected: no errors.

- [ ] **Step 2: Verify no binding conflicts between files**

Manually verify:
- Hyprland `Super+D` = rofi launcher
- GNOME `Super+D` = search-light
- Both have `Super+Q` + `Alt+F4` for close
- Both have `Super+F` for fullscreen
- Both have `Super+1-9,0` / `Super+Shift+1-9,0` for workspaces
- Both have `Super+h/j/k/l` for focus (Forge in GNOME)
- Both have `Super+Shift+h/j/k/l` for swap
- Both have `Super+Alt+h/j/k/l` for resize
- Both have `Super+Backspace` for lock
- Both have `Ctrl+Super+Backspace` for power
- Both have `Print`/`Shift+Print`/`Ctrl+Print` for screenshots
- No `Ctrl+Alt` bindings remain in GNOME (except `Ctrl+Alt+T` for terminal which passes through Ghostty)

- [ ] **Step 3: Lint**

```bash
just lint-check
```

Expected: passes. If formatting issues, run `just lint-fix` and amend.
