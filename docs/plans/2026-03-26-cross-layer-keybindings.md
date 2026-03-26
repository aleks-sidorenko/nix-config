# Cross-Layer Keybindings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the cross-layer keybinding scheme across Ghostty, Neovim, Hyprland, GNOME, and AeroSpace configs.

**Architecture:** Declarative Nix config changes — each task modifies one config file to match the spec in `docs/specs/2026-03-26-cross-layer-keybindings-design.md`. Reference `docs/hotkeys.md` for the complete binding table.

**Tech Stack:** Nix, nixvim, Ghostty config, Hyprland, dconf/GNOME, AeroSpace TOML

---

### Task 1: Ghostty — Rewrite keybindings to Alt-based scheme

**Files:**
- Modify: `modules/home/cli/terminals/ghostty/default.nix:51-189`

- [ ] **Step 1: Replace the keybind array**

Replace the entire `keybind` list with the new Alt-based scheme. Key changes:
- Split navigation: `alt+shift+hjkl` → `alt+hjkl` (and arrows: `alt+shift+arrows` → `alt+arrows`)
- Split creation: `ctrl+shift+hjkl/arrows` → `alt+shift+hjkl/arrows`
- Logical splits: `ctrl+shift+|/-` → `alt+shift+|/-`
- Split resize: `alt+shift+ctrl+hjkl/arrows` → `alt+ctrl+hjkl/arrows`
- Split zoom: `ctrl+shift+enter` → `alt+ctrl+enter`
- Tab switch: `alt+ctrl+1-9` → `alt+1-9`
- Tab new/close: `alt+ctrl+n/q` → `alt+shift+n/q`
- Window new/close: `ctrl+shift+n/q` → `alt+shift+w/x`
- Jump to prompt: `ctrl+shift+page_up/down` → `alt+page_up/down`
- Add tab cycle: `alt+[` (prev), `alt+]` (next)
- Remove `alt+f4=quit` (keep close via `alt+shift+x`)
- Preserve: clipboard (`ctrl+shift+c/v/a`), config (`ctrl+shift+,/p/i`), font/display (`ctrl`), scroll, selection, prefix mode, write-to-file, Claude Code

- [ ] **Step 2: Verify build**

Run: `nix eval .#homeConfigurations --apply 'x: "ok"'` or check with `nix flake check`

- [ ] **Step 3: Commit**

```bash
git add modules/home/cli/terminals/ghostty/default.nix
git commit -m "feat(ghostty): migrate keybindings to Alt-based scheme"
```

### Task 2: Neovim keymaps — Remove conflicts, add new bindings

**Files:**
- Modify: `packages/nvim/keymaps.nix`

- [ ] **Step 1: Remove conflicting Alt bindings**

Remove these keymaps:
- `<A-[>` / `<A-]>` (line begin/end) — lines 53-75
- `<A-S-[>` / `<A-S-]>` (file begin/end) — lines 76-98
- `<A-j>` / `<A-k>` in normal, insert, visual modes (line move) — lines 168-215
- `<C-x>` (close window) — lines 469-476

- [ ] **Step 2: Add new bindings**

Add these keymaps:
- `H` → `^` (line begin), `L` → `$` (line end) — normal + visual
- `g[` → `^`, `g]` → `$` (line begin/end alternative) — normal + visual
- `g{` → `gg`, `g}` → `G` (file begin/end) — normal + visual
- `<C-S-j>` / `<C-S-k>` → move line down/up — normal, insert, visual
- `<leader>1` through `<leader>9` → `BufferLineGoToBuffer` 1-9
- `<leader>wh/j/k/l` → focus window (mirrors Ctrl+HJKL)
- `<leader>w-` → split below (`<C-W>s`)
- `<leader>wm` → maximize/zoom toggle (`:only` or use `<C-W>o`)
- `<leader>w=` → equalize sizes (`<C-W>=`)

- [ ] **Step 3: Commit**

```bash
git add packages/nvim/keymaps.nix
git commit -m "feat(nvim): align keymaps with cross-layer scheme"
```

### Task 3: Neovim bufferline — Remove duplicates, add discoverability bindings

**Files:**
- Modify: `packages/nvim/plugins/ui/bufferline.nix`

- [ ] **Step 1: Remove duplicate bindings**

Remove:
- `<S-l>` (cycle next buffer) — lines 44-51, duplicate of `]b`
- `<S-h>` (cycle prev buffer) — lines 53-60, duplicate of `[b`
- `<S-x>` (delete buffer) — lines 79-87, duplicate of `<leader>bq`

- [ ] **Step 2: Add discoverability bindings**

Add:
- `<leader>b[` → `BufferLineCyclePrev` (mirrors `[b`)
- `<leader>b]` → `BufferLineCycleNext` (mirrors `]b`)

- [ ] **Step 3: Commit**

```bash
git add packages/nvim/plugins/ui/bufferline.nix
git commit -m "feat(nvim): clean up bufferline bindings for cross-layer scheme"
```

### Task 4: Hyprland — Remove Alt+Ctrl move, add Super+M maximize

**Files:**
- Modify: `modules/home/desktops/hyprland/keybindings.nix:120-130`

- [ ] **Step 1: Remove `ALTCTRL` movewindow bindings**

Remove lines 120-123:
```nix
"ALTCTRL,L, movewindow,r"
"ALTCTRL,H, movewindow,l"
"ALTCTRL,K, movewindow,u"
"ALTCTRL,J, movewindow,d"
```

- [ ] **Step 2: Add `SUPER,M` maximize toggle**

Add to the `bind` list:
```nix
"SUPER, M, fullscreen, 1"
```

(`fullscreen, 1` is Hyprland's "maximize" mode — fills workspace without hiding bar)

- [ ] **Step 3: Commit**

```bash
git add modules/home/desktops/hyprland/keybindings.nix
git commit -m "feat(hyprland): remove Alt+Ctrl move, add Super+M maximize"
```

### Task 5: GNOME — Add Super+M maximize toggle

**Files:**
- Modify: `modules/home/desktops/gnome/keybindings.nix:139`

- [ ] **Step 1: Update `toggle-maximized` binding**

Change:
```nix
toggle-maximized = [ "<Alt>F10" ];
```
To:
```nix
toggle-maximized = [ "<Super>m" "<Alt>F10" ];
```

(Keep `Alt+F10` as legacy fallback alongside new `Super+M`)

- [ ] **Step 2: Commit**

```bash
git add modules/home/desktops/gnome/keybindings.nix
git commit -m "feat(gnome): add Super+M as toggle-maximized binding"
```

### Task 6: AeroSpace — Add Alt+Cmd+M maximize toggle

**Files:**
- Modify: `modules/home/desktops/aerospace/keybindings.nix:26`

- [ ] **Step 1: Add maximize binding**

After the fullscreen line, add:
```
# Maximize (fill workspace) — Alt+Cmd+M (Linux: Super+M)
alt-cmd-m = 'fullscreen'
```

(AeroSpace's `fullscreen` command is equivalent to maximize — it fills the workspace)

- [ ] **Step 2: Commit**

```bash
git add modules/home/desktops/aerospace/keybindings.nix
git commit -m "feat(aerospace): add Alt+Cmd+M maximize toggle"
```

### Task 7: Validate

- [ ] **Step 1: Run lint**

```bash
just lint-check
```

- [ ] **Step 2: Run flake check**

```bash
nix flake check
```
