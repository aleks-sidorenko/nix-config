# Keybinding Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Evict three Ghostty bindings that steal bare-`Ctrl` chords from Neovim, then wire `C--`/`C-|` splits in Neovim, per the contract in `docs/specs/2026-08-17-keybinding-contract-design.md`.

**Architecture:** Two independent git repos. `nix-config` owns the Ghostty terminal config; `nix-nvim` owns the Neovim config (consumed by `nix-config` as a flake input). Ghostty must be evicted and applied *first* so the freed chords actually reach Neovim, which is a prerequisite for pinning the `C--`/`C-|` notation.

**Tech Stack:** Nix (snowfall-lib), home-manager, nixvim, Ghostty (Kitty keyboard protocol), Telescope.

**Verification model:** These are declarative keybindings — there is no unit-test harness. Each task's "test" is: (1) `format` clean, (2) config **builds** (evaluates), and (3) a **live behavioral check** in a running session. Live checks are mandatory, not optional — a green build does not prove a chord is delivered.

**Critical for all Neovim live checks (Tasks 2-4):** run `just run` from a Ghostty window that already has Task 1 applied (freed chords). Running nvim in an un-evicted terminal will show a false failure — the chord never reaches nvim because Ghostty still eats it.

**Repos & branches:**
- `nix-config` — branch `refactor/keybinding-contract` (already checked out; spec already committed here)
- `nix-nvim` (`~/Projects/Self/nix-nvim`) — branch `refactor/keybinding-contract` (created in Task 2)

---

## Task 1: Evict Ghostty offenders (nix-config)

**Files:**
- Modify: `modules/home/cli/terminals/ghostty/default.nix:145-157`

Move font size + fullscreen into the Alt bucket and config/reload into the `ctrl+a` prefix, freeing `C--`, `C-+`, `C-0`, `C-enter`, `C-;` for Neovim. `${prefix}` is `ctrl+a` (defined at line 14); prefix subkeys `c`/`r` are unused.

- [ ] **Step 1: Apply the eviction edits**

In the `keybind` list, replace lines 145-157 wholesale — the font/display block, the configuration block, **and** the `ctrl+shift+q/p/i` lines (which are reproduced unchanged in the block below, so the replacement is 1:1 with no duplication):

```nix
          # Font/Display (Alt — terminal-owned, keeps bare Ctrl free for Neovim)
          "alt+=increase_font_size:1"
          "alt+-=decrease_font_size:1"
          "alt+0=reset_font_size"
          "alt+enter=toggle_fullscreen"

          # Configuration (prefix — rare, keeps C-; free for Neovim)
          "${prefix}>c=open_config"
          "${prefix}>r=reload_config"
          "ctrl+shift+q=quit"
          "ctrl+shift+p=toggle_command_palette"
          "ctrl+shift+i=inspector:toggle"
```

Note: this removes the old `# ctrl+,/. freed for Neovim move line` comment (superseded by the contract) and the `ctrl++`/`ctrl+-`/`ctrl+0`/`ctrl+enter`/`ctrl+;`/`ctrl+shift+;` lines. Leave everything else in the file untouched (copy/paste, scroll, selection, write-to-file prefix block, `shift+enter`).

- [ ] **Step 2: Format**

Run: `just format modules/home/cli/terminals/ghostty/default.nix`
Expected: no diff or a clean reformat, exit 0.

- [ ] **Step 3: Build (config evaluates)**

Run: `just build`
Expected: builds without error. (This proves the Nix evaluates; it does NOT prove key delivery.)

- [ ] **Step 4: Apply so the new bindings take effect**

Run: `nh home switch`
Expected: home-manager generation switches successfully. Restart Ghostty (or open a new instance) so the new keybind config loads.

- [ ] **Step 5: Live behavioral check (Ghostty side)**

In the restarted Ghostty:
- `alt+-` / `alt+=` / `alt+0` — font shrinks / grows / resets.
- `alt+enter` — toggles fullscreen.
- `ctrl+a` then `c` — opens config; `ctrl+a` then `r` — reloads config.
- Confirm `ctrl+-` / `ctrl++` / `ctrl+0` / `ctrl+enter` / `ctrl+;` now do **nothing** in Ghostty (they should fall through to the shell/program).

Expected: all pass. If any relocated action fails to fire, stop and diagnose before proceeding.

- [ ] **Step 6: Commit**

```bash
git add modules/home/cli/terminals/ghostty/default.nix
git commit -m "refactor(ghostty): evict font/fullscreen/config off bare Ctrl per keybinding contract"
```

---

## Task 2: Branch nix-nvim + pin C--/C-| notation

**This task depends on Task 1 being applied** — the chords must pass through Ghostty before Neovim can observe them.

**Files:** none modified yet (investigation task).

- [ ] **Step 1: Create the branch**

```bash
cd ~/Projects/Self/nix-nvim
git checkout -b refactor/keybinding-contract
git branch --show-current   # -> refactor/keybinding-contract
```

- [ ] **Step 2: Launch the built Neovim**

Run: `just run`
Expected: nvim opens.

- [ ] **Step 3: Probe the received keycodes**

In normal mode, set temporary probes and press the chords:

```vim
:lua vim.keymap.set('n','<C-->',function() print('C-- OK') end)
:lua vim.keymap.set('n','<C-|>',function() print('C-bar (C-|) OK') end)
:lua vim.keymap.set('n','<C-Bslash>',function() print('C-Bslash OK') end)
```

Press `C--`, then `C-|`, then (if `C-|` prints nothing) `C-\`. Note which notation actually fires. Cross-check with insert-mode `Ctrl-V` + the chord to see the raw sequence if a probe is silent.

Expected outcome, recorded for Tasks 3-4:
- `C--` → `<C-->` (expected to work).
- `C-|` → `<C-|>` if the Kitty protocol delivers `ctrl+shift+\`; else **fallback** to bare `C-\` = `<C-Bslash>` (per spec). Record the chosen vertical-split notation as `VSPLIT_KEY`.

- [ ] **Step 4: Record the decision**

Note the pinned notations in the Task 3/4 edits below (replace `<C-|>` with `VSPLIT_KEY` if the fallback was needed) and, if the fallback was used, add a one-line note to the spec's "Risks / verification" section documenting the deviation. No commit yet (no file changes unless the spec note is added — if so, commit that note in `nix-config`).

---

## Task 3: Telescope C--/C-| splits (nix-nvim)

**Files:**
- Modify: `nvim/plugins/navigation/telescope.nix:25-44`

Add `C--`/`C-|` split actions in both insert and normal mode; remove the bare `-`/`|` normal-mode hack; keep Telescope's default insert splits (`C-v`/`C-x`) as-is (additive).

- [ ] **Step 1: Edit the `mappings` block**

Replace the insert (`i`) and normal (`n`) mapping blocks (lines 25-44) with (using the `VSPLIT_KEY` pinned in Task 2 — shown here as `<C-|>`):

```nix
        mappings = {
          i = {
            "<C-j>".__raw = "require('telescope.actions').move_selection_next";
            "<C-k>".__raw = "require('telescope.actions').move_selection_previous";
            "<C-n>" = false;
            "<C-p>" = false;
            # Splits: bare Ctrl now reaches Neovim (Ghostty no longer binds C--).
            # C-v/C-x (Telescope defaults) are retained; these are additive.
            "<C-->".__raw = "require('telescope.actions').select_horizontal";
            "<C-|>".__raw = "require('telescope.actions').select_vertical";
          };
          n = {
            "<C-j>".__raw = "require('telescope.actions').move_selection_next";
            "<C-k>".__raw = "require('telescope.actions').move_selection_previous";
            "<C-n>" = false;
            "<C-p>" = false;
            # Splits mirror insert mode: C-- horizontal, C-| vertical.
            "<C-->".__raw = "require('telescope.actions').select_horizontal";
            "<C-|>".__raw = "require('telescope.actions').select_vertical";
          };
        };
```

- [ ] **Step 2: Format + build**

Run: `just format nvim/plugins/navigation/telescope.nix && just build`
Expected: clean format, build succeeds.

- [ ] **Step 3: Live behavioral check**

Run: `just run`, open a picker (`<leader><space>` find files), then in the picker:
- Insert mode: `C--` opens the highlighted file in a horizontal split; `C-|` in a vertical split.
- Normal mode (`<Esc>` in picker): same.
- Confirm `C-v`/`C-x` still split (defaults intact).

Expected: all pass. If `C-|` does nothing, confirm `VSPLIT_KEY` matches Task 2's finding.

- [ ] **Step 4: Commit**

```bash
cd ~/Projects/Self/nix-nvim
git add nvim/plugins/navigation/telescope.nix
git commit -m "refactor(telescope): C--/C-| splits now that Ghostty frees them"
```

---

## Task 4: Neovim window-split fast path (nix-nvim)

**Files:**
- Modify: `nvim/keymaps.nix` (append to the `keymaps` list; the existing `<leader>-`/`<leader>|` window splits are at `keymaps.nix:661-678` and stay unchanged)

Add `C--`/`C-|` as window split-create, alongside the existing `<leader>-`/`<leader>|` (which stay as the discoverable path).

- [ ] **Step 1: Add the keymaps**

Append to the `keymaps` list in `nvim/keymaps.nix` (use `VSPLIT_KEY` for the vertical entry):

```nix
    # Window splits — fast path (Ctrl); mirrors <leader>-/<leader>| and
    # Telescope's C--/C-|. Ghostty no longer intercepts these.
    {
      mode = "n";
      key = "<C-->";
      action = "<C-w>s";
      options = {
        desc = "Split Window Below";
        remap = true;
      };
    }
    {
      mode = "n";
      key = "<C-|>";
      action = "<C-w>v";
      options = {
        desc = "Split Window Right";
        remap = true;
      };
    }
```

- [ ] **Step 2: Format + build**

Run: `just format nvim/keymaps.nix && just build`
Expected: clean format, build succeeds.

- [ ] **Step 3: Live behavioral check**

Run: `just run`, then in normal mode:
- `C--` splits the window horizontally (below).
- `C-|` splits vertically (right).
- Confirm `<leader>-` / `<leader>|` still work (unchanged).

Expected: all pass.

- [ ] **Step 4: Commit**

```bash
cd ~/Projects/Self/nix-nvim
git add nvim/keymaps.nix
git commit -m "feat(keymaps): C--/C-| window splits as Ctrl fast path"
```

---

## Task 5 (integration, optional): pull new nvim into nix-config

Only needed to make the Neovim changes live on the actual system (vs. verified standalone via `just run`). Do after `nix-nvim` changes are merged/pushed, since the flake input tracks a ref.

**Files:**
- Modify: `flake.lock` (via `nix flake update`)

- [ ] **Step 1: Bump the nix-nvim input**

From `nix-config`: `just update <nix-nvim-input-name>` (find the exact input name in `flake.nix`).

- [ ] **Step 2: Build + apply**

Run: `just build` then `nh home switch`.
Expected: builds and switches; Neovim inside Ghostty now has the new splits.

- [ ] **Step 3: Commit**

```bash
git add flake.lock
git commit -m "build(flake): bump nix-nvim for keybinding contract"
```

---

## Done criteria

- Ghostty: `C--`/`C-+`/`C-0`/`C-enter`/`C-;` pass through; font/fullscreen on Alt; config on `ctrl+a>c/r`.
- Telescope + Neovim windows: `C--` horizontal split, `C-|` (or fallback `C-\`) vertical split, all live-verified.
- Contract documented in the spec; comments in both repos reference it, not the old workaround.
- Both repos committed on `refactor/keybinding-contract`.
