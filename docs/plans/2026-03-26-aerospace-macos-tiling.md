# AeroSpace macOS Tiling WM Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add AeroSpace tiling window manager to macOS with keybindings aligned to the unified Hyprland/GNOME scheme.

**Architecture:** Two-module split following the Hyprland pattern — a darwin module installs AeroSpace via Homebrew, a home-manager module generates `~/.aerospace.toml` with tiling config and keybindings. The work roles enable both modules.

**Tech Stack:** Nix (snowfall-lib modules), nix-darwin (Homebrew), home-manager (`home.file`), AeroSpace TOML config

**Spec:** `docs/specs/2026-03-26-aerospace-macos-tiling-design.md`

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `modules/darwin/desktops/aerospace/default.nix` | Create | Darwin module: option definition, Homebrew tap + cask installation |
| `modules/home/desktops/aerospace/default.nix` | Create | Home-manager module: option definition, imports keybindings string, generates `~/.aerospace.toml` |
| `modules/home/desktops/aerospace/keybindings.nix` | Create | Plain Nix expression returning a TOML keybindings string (not a module) |
| `modules/darwin/roles/work/default.nix` | Modify | Remove Rectangle, enable AeroSpace darwin module |
| `modules/home/roles/work/default.nix` | Modify | Enable AeroSpace home-manager module |

---

### Task 1: Darwin Module (Homebrew Installation)

**Files:**
- Create: `modules/darwin/desktops/aerospace/default.nix`

- [ ] **Step 1: Create the darwin module**

Follow the pattern from `modules/darwin/communication/slack/default.nix`. The module declares the enable option, adds the Homebrew tap and cask. The tap is set via nix-darwin's `homebrew.taps` directly (bypassing the `${namespace}.system.homebrew` wrapper which does not expose `taps`).

```nix
{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktops.aerospace;
in
{
  options.${namespace}.desktops.aerospace = with types; {
    enable = mkBoolOpt false "Enable AeroSpace tiling window manager";
  };

  config = mkIf cfg.enable {
    homebrew.taps = [ "nikitabobko/tap" ];
    ${namespace}.system.homebrew.casks = [
      "aerospace"
    ];
  };
}
```

- [ ] **Step 2: Validate syntax**

Run: `nix flake check --no-build 2>&1 | head -20`

Expected: No syntax errors related to aerospace. There may be other errors due to missing system-specific evaluation — that's fine. If `error: syntax error` appears mentioning the new file, fix it.

- [ ] **Step 3: Commit**

```bash
git add modules/darwin/desktops/aerospace/default.nix
git commit -m "feat(aerospace): add darwin module for Homebrew installation"
```

---

### Task 2: Home-Manager Keybindings String

**Files:**
- Create: `modules/home/desktops/aerospace/keybindings.nix`

- [ ] **Step 1: Create the keybindings file**

This is a plain Nix expression (not a module) that returns a TOML string. It is imported directly by `default.nix` via `import ./keybindings.nix`, NOT auto-imported by snowfall-lib.

AeroSpace TOML binding format: `<key-combo> = '<command>'` under `[mode.main.binding]`.
AeroSpace modifier names: `alt` (Option), `cmd`, `ctrl`, `shift`. Combined with hyphens: `alt-cmd-h`.

```nix
''
[mode.main.binding]

# Window focus — Alt+Cmd+hjkl (Linux: Super+hjkl)
alt-cmd-h = 'focus left'
alt-cmd-j = 'focus down'
alt-cmd-k = 'focus up'
alt-cmd-l = 'focus right'

# Swap windows — Alt+Cmd+Shift+hjkl (Linux: Super+Shift+hjkl)
alt-cmd-shift-h = 'move left'
alt-cmd-shift-j = 'move down'
alt-cmd-shift-k = 'move up'
alt-cmd-shift-l = 'move right'

# Resize windows — Ctrl+Cmd+hjkl (Linux: Super+Alt+hjkl)
ctrl-cmd-h = 'resize width -50'
ctrl-cmd-j = 'resize height -50'
ctrl-cmd-k = 'resize height +50'
ctrl-cmd-l = 'resize width +50'

# Close window — Alt+Cmd+Q (Linux: Super+Q)
alt-cmd-q = 'close'

# Fullscreen — Alt+Cmd+F (Linux: Super+F)
alt-cmd-f = 'fullscreen'

# Workspaces — Alt+Cmd+N (Linux: Super+N)
alt-cmd-1 = 'workspace 1'
alt-cmd-2 = 'workspace 2'
alt-cmd-3 = 'workspace 3'
alt-cmd-4 = 'workspace 4'
alt-cmd-5 = 'workspace 5'
alt-cmd-6 = 'workspace 6'
alt-cmd-7 = 'workspace 7'
alt-cmd-8 = 'workspace 8'
alt-cmd-9 = 'workspace 9'
alt-cmd-0 = 'workspace 10'

# Move window to workspace — Alt+Cmd+Shift+N (Linux: Super+Shift+N)
alt-cmd-shift-1 = 'move-node-to-workspace 1'
alt-cmd-shift-2 = 'move-node-to-workspace 2'
alt-cmd-shift-3 = 'move-node-to-workspace 3'
alt-cmd-shift-4 = 'move-node-to-workspace 4'
alt-cmd-shift-5 = 'move-node-to-workspace 5'
alt-cmd-shift-6 = 'move-node-to-workspace 6'
alt-cmd-shift-7 = 'move-node-to-workspace 7'
alt-cmd-shift-8 = 'move-node-to-workspace 8'
alt-cmd-shift-9 = 'move-node-to-workspace 9'
alt-cmd-shift-0 = 'move-node-to-workspace 10'

# Focus monitor — Ctrl+Cmd+Shift+Arrow (Linux: Super+Ctrl+Arrow)
ctrl-cmd-shift-left = 'focus-monitor left'
ctrl-cmd-shift-right = 'focus-monitor right'

# Move window to monitor — Ctrl+Cmd+Shift+hl (Linux: N/A)
ctrl-cmd-shift-h = 'move-node-to-monitor left'
ctrl-cmd-shift-l = 'move-node-to-monitor right'

# App launcher (Raycast) — Alt+Cmd+D (Linux: Super+D)
alt-cmd-d = 'exec-and-forget open -a "Raycast"'
''
```

- [ ] **Step 2: Commit**

```bash
git add modules/home/desktops/aerospace/keybindings.nix
git commit -m "feat(aerospace): add unified keybindings configuration"
```

---

### Task 3: Home-Manager Module (AeroSpace Config Generation)

**Files:**
- Create: `modules/home/desktops/aerospace/default.nix`

- [ ] **Step 1: Create the home-manager module**

The module declares the enable option and generates `~/.aerospace.toml`. It imports `keybindings.nix` as a plain Nix expression (via `import`), not as a snowfall-lib module. Do NOT use `imports = lib.snowfall.fs.get-non-default-nix-files ./.;` — that would try to auto-import `keybindings.nix` as a module, but it's a plain expression returning a string.

```nix
{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktops.aerospace;
  keybindings = import ./keybindings.nix;
in
{
  options.${namespace}.desktops.aerospace = with types; {
    enable = mkEnableOption "AeroSpace tiling window manager";
  };

  config = mkIf cfg.enable {
    home.file.".aerospace.toml".text = ''
      # AeroSpace tiling window manager configuration
      # Generated by nix-config — do not edit manually

      start-at-login = true
      enable-normalization-flatten-containers = true
      enable-normalization-opposite-orientation-for-nested-containers = true
      accordion-padding = 30
      default-root-container-layout = 'tiles'
      default-root-container-orientation = 'auto'

      [gaps]
      inner.horizontal = 10
      inner.vertical = 10
      outer.left = 10
      outer.bottom = 10
      outer.top = 10
      outer.right = 10

    '' + keybindings;
  };
}
```

- [ ] **Step 2: Validate syntax**

Run: `nix flake check --no-build 2>&1 | head -20`

Expected: No syntax errors related to aerospace modules.

- [ ] **Step 3: Commit**

```bash
git add modules/home/desktops/aerospace/default.nix
git commit -m "feat(aerospace): add home-manager module for config generation"
```

---

### Task 4: Enable in Work Roles

**Files:**
- Modify: `modules/darwin/roles/work/default.nix`
- Modify: `modules/home/roles/work/default.nix`

- [ ] **Step 1: Update darwin work role**

In `modules/darwin/roles/work/default.nix`, make two changes inside the `${namespace}` block:

1. Remove `"rectangle"` from the `roles.common.homebrew.casks` list:
```nix
          casks = [
            "raycast" # Spotlight replacement
          ];
```

2. Add `desktops.aerospace = enabled;` as a sibling to `communication`, `browsers`, etc.:
```nix
    ${namespace} = {
      # Inherit common configuration
      roles.common = {
        ...
      };

      desktops.aerospace = enabled;

      communication = {
        ...
      };
      ...
    };
```

- [ ] **Step 2: Update home-manager work role**

In `modules/home/roles/work/default.nix`, add `desktops.aerospace = enabled;` inside the `${namespace}` block, as a sibling to `roles`, `cli`, `browsers`, etc.:

```nix
    ${namespace} = {
      roles = { ... };

      desktops.aerospace = enabled;

      cli.tools.git.lfs = true;
      ...
    };
```

- [ ] **Step 3: Validate syntax**

Run: `nix flake check --no-build 2>&1 | head -20`

Expected: No syntax errors.

- [ ] **Step 4: Commit**

```bash
git add modules/darwin/roles/work/default.nix modules/home/roles/work/default.nix
git commit -m "feat(aerospace): enable in work roles, replace Rectangle"
```

---

### Task 5: Build Validation

- [ ] **Step 1: Build the darwin configuration**

Run: `nix build .#darwinConfigurations.workbook.system --dry-run 2>&1 | tail -20`

Expected: Successful dry-run evaluation (no Nix evaluation errors). Actual build requires macOS but evaluation should succeed.

If evaluation fails, read the error and fix the offending module. Common issues:
- Option type mismatch (check `mkOption` types)
- Missing imports (snowfall-lib auto-discovers, but verify)
- Namespace typos

- [ ] **Step 2: Build the home-manager configuration**

Run: `nix build .#homeConfigurations."oleksandrsy@workbook".activationPackage --dry-run 2>&1 | tail -20`

Expected: Successful dry-run evaluation.

- [ ] **Step 3: Verify generated TOML content**

Build the home-manager config and inspect the generated TOML:

```bash
nix build .#homeConfigurations."oleksandrsy@workbook".activationPackage 2>&1 | tail -20
```

Then find and read the generated `.aerospace.toml` in the result to verify it contains all expected sections: general settings, gaps, and keybindings with the correct AeroSpace commands.

- [ ] **Step 4: Commit any fixes**

If fixes were needed, commit them:
```bash
git add -u
git commit -m "fix(aerospace): address build validation issues"
```
