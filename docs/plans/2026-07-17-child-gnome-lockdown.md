# Child GNOME Split + UI Lockdown — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the `child` profile a minimal, locked-down GNOME (no wifi/bluetooth toggling, no Settings, minimal extensions) by splitting the home-manager GNOME module into a shared base + per-profile layers, and adding a NixOS polkit deny for child users — leaving the adult (`alexander`) desktop byte-for-byte unchanged.

**Architecture:** `modules/home/desktops/gnome/default.nix` becomes user-agnostic infra + a `profile` enum option. Adult-only content moves to `profiles/adult/default.nix`; a new `profiles/child/default.nix` holds the minimal + lockdown config; both are auto-discovered by snowfall (nested `default.nix`, like `addons/default.nix`). `keybindings.nix` stays top-level but is re-gated to `profile == "adult"`. A new NixOS module writes a `00-`-prefixed polkit rule denying NetworkManager enable/disable to child users.

**Tech Stack:** Nix, snowfall-lib, home-manager, GNOME dconf, polkit.

**Spec:** `docs/specs/2026-07-17-child-gnome-lockdown-design.md`

**Conventions for this repo:** No unit-test framework — "tests" are `nix eval` assertions and `just build`. Verify with the exact eval commands given. Commit after each task. Commits are unsigned in an agent session (`git -c commit.gpgsign=false commit`); the branch is re-signed before push. Run `just format` before the final commit of a task that adds/edits `.nix` files.

---

## File Structure

- `modules/home/desktops/gnome/default.nix` — **modify**: base infra + `profile`/`allowedApps` options; adult-only dconf/packages removed.
- `modules/home/desktops/gnome/keybindings.nix` — **modify**: re-gate guard to `profile == "adult"`.
- `modules/home/desktops/gnome/profiles/adult/default.nix` — **create**: adult extensions, tray, vitals, dock.
- `modules/home/desktops/gnome/profiles/child/default.nix` — **create**: minimal packages/extensions, restricted dock, lockdown dconf, hidden Settings.
- `modules/home/desktops/gnome/monitors.nix`, `addons/default.nix` — unchanged.
- `modules/home/roles/child/default.nix` — **modify**: `launcher = {...}` → `profile = "child"; allowedApps = …`.
- `modules/nixos/users/child-lockdown/default.nix` — **create**: polkit deny for child users.

---

## Task 0: Capture adult baseline (safety net)

Snapshot the adult GNOME config so we can prove it is unchanged after the split.

**Files:** none (writes to scratchpad).

- [ ] **Step 1: Snapshot adult dconf + packages**

Run (from repo root):
```bash
S=/private/tmp/claude-501/-Users-oleksandrsy--nix-config/1cf5d687-fed2-4f45-88fd-3920149c72eb/scratchpad
nix eval --json '.#nixosConfigurations.homebook.config.home-manager.users.alexander.dconf.settings' > "$S/adult-dconf-before.json" 2>/dev/null
nix eval --json '.#nixosConfigurations.homebook.config.home-manager.users.alexander.home.packages' --apply 'ps: map (p: p.name) ps' > "$S/adult-pkgs-before.json" 2>/dev/null
wc -c "$S/adult-dconf-before.json" "$S/adult-pkgs-before.json"
```
Expected: both files non-empty (dconf several KB). If `dconf.settings` fails to serialize as JSON, fall back to snapshotting the two JSON-safe leaves used in later checks:
```bash
for k in enabled-extensions favorite-apps; do
  nix eval --json ".#nixosConfigurations.homebook.config.home-manager.users.alexander.dconf.settings.\"org/gnome/shell\".$k" > "$S/adult-$k-before.json" 2>/dev/null
done
```

- [ ] **Step 2: Record the git baseline**

Run: `git rev-parse HEAD > "$S/baseline-sha.txt"` (lets us `git diff` the whole change later).

No commit (scratchpad only).

---

## Task 1: Base module — add `profile`, extract adult-only content

Split `default.nix`: keep shared infra, add the `profile` enum + `allowedApps`, and **move** all adult-only content out (it lands in Task 2). Re-gate `keybindings.nix`. This is one atomic change because the moved dconf keys (`enabled-extensions`, `favorite-apps`) cannot be defined in two files at once.

**Files:**
- Modify: `modules/home/desktops/gnome/default.nix`
- Modify: `modules/home/desktops/gnome/keybindings.nix:13`
- Create: `modules/home/desktops/gnome/profiles/adult/default.nix`

- [ ] **Step 1: Rewrite the options block in `default.nix`**

Replace the `options.${namespace}.desktops.gnome` block (`default.nix:16-27`) with:
```nix
  options.${namespace}.desktops.gnome = {
    enable = mkEnableOption "Enable GNOME desktop environment";
    profile = mkOpt (types.enum [ "adult" "child" ]) "adult" "GNOME setup preset: full adult desktop or minimal locked-down child desktop.";
    favoriteApps =
      mkOpt (types.listOf types.str) [ ]
        "Desktop file names (without .desktop) pinned to the dock on the adult profile.";
    allowedApps =
      mkOpt (types.listOf types.str) [ ]
        "Desktop file names (without .desktop) that make up the dock on the child profile.";
  };
```

- [ ] **Step 2: Strip adult-only content from `default.nix` config**

In the `config = mkIf cfg.enable { ... }` block:
- Remove the entire `home.packages = with pkgs; [ … ];` list (`default.nix:46-61`) — it moves to the adult profile.
- In `dconf.settings`, delete the `restricted = cfg.launcher.restrict;` let-binding and the `// optionalAttrs restricted { … }` tail (`default.nix:75, 152-159`).
- Remove the whole `"org/gnome/shell" = { … };` attribute (`default.nix:96-120`) — `disable-user-extensions`, `favorite-apps`, `enabled-extensions` all move to the profiles.
- Remove `"org/gnome/shell/extensions/appindicator"` (`:122-124`) and `"org/gnome/shell/extensions/vitals"` (`:126-137`) — move to adult.
- **Keep** in the base: `stylix.targets.gnome`, the `${namespace}` addons wiring (`:30-42`), `org/gnome/desktop/interface` (`:79-84`), `org/gnome/desktop/input-sources` (`:86-90`), `org/gnome/desktop/wm/preferences` focus-mode (`:92-94`), `org/gnome/settings-daemon/plugins/power` (`:140-145`), `org/gnome/desktop/session` (`:147-149`), `home.sessionVariables`, the gnome-keyring autostart override, and `xdg.portal` (`:177-186`).

After this step `default.nix` has no `pkgs` uses beyond `xdg.portal`; keep `pkgs` in the function args (portals use it).

- [ ] **Step 3: Create `profiles/adult/default.nix`**

```nix
{
  config,
  pkgs,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktops.gnome;
in
{
  config = mkIf (cfg.enable && cfg.profile == "adult") {
    home.packages = with pkgs; [
      dconf-editor
      gnome-tweaks
      gnomeExtensions.user-themes
      gnomeExtensions.space-bar
      gnomeExtensions.hibernate-status-button
      gnomeExtensions.forge
      gnomeExtensions.appindicator
      gnomeExtensions.just-perfection
      gnomeExtensions.pano
      gnomeExtensions.search-light
      gnomeExtensions.gsconnect
      gnomeExtensions.caffeine
      gnomeExtensions.launch-new-instance
      gnomeExtensions.vitals
    ];

    dconf.settings = {
      "org/gnome/shell" = {
        disable-user-extensions = false;
        favorite-apps = [ "org.gnome.Nautilus.desktop" ] ++ map (app: "${app}.desktop") cfg.favoriteApps;
        enabled-extensions = [
          "user-theme@gnome-shell-extensions.gcampax.github.com"
          "launch-new-instance@gnome-shell-extensions.gcampax.github.com"
          "space-bar@luchrioh"
          "hibernate-status@dromi"
          "appindicatorsupport@rgcjonas.gmail.com"
          "forge@jmmaranan.com"
          "pano@elhan.io"
          "search-light@icedman.github.com"
          "gsconnect@andyholmes.github.io"
          "caffeine@patapon.info"
          "Vitals@CoreCoding.com"
        ];
      };

      "org/gnome/shell/extensions/appindicator" = {
        legacy-tray-enabled = true;
      };

      "org/gnome/shell/extensions/vitals" = {
        show-temperature = true;
        show-voltage = false;
        show-fan = true;
        show-memory = true;
        show-processor = true;
        show-storage = true;
        hot-sensors = [ "CPU" ];
        position-in-panel = "right";
        refresh-time = 2;
      };
    };
  };
}
```

- [ ] **Step 4: Re-gate `keybindings.nix`**

In `keybindings.nix`, change the guard (`:13`) from:
```nix
  config = mkIf cfg.enable {
```
to:
```nix
  config = mkIf (cfg.enable && cfg.profile == "adult") {
```

- [ ] **Step 5: Format and evaluate**

Run:
```bash
just format modules/home/desktops/gnome
nix eval --json '.#nixosConfigurations.homebook.config.home-manager.users.alexander.dconf.settings."org/gnome/shell".enabled-extensions' 2>/dev/null
```
Expected: the full 11-extension list (user-theme … Vitals) — identical to baseline, proving adult is unchanged.

- [ ] **Step 6: Prove adult is unchanged vs. baseline**

Run:
```bash
S=/private/tmp/claude-501/-Users-oleksandrsy--nix-config/1cf5d687-fed2-4f45-88fd-3920149c72eb/scratchpad
nix eval --json '.#nixosConfigurations.homebook.config.home-manager.users.alexander.dconf.settings' 2>/dev/null > "$S/adult-dconf-after.json"
diff <(jq -S . "$S/adult-dconf-before.json") <(jq -S . "$S/adult-dconf-after.json") && echo "ADULT DCONF UNCHANGED"
nix eval --json '.#nixosConfigurations.homebook.config.home-manager.users.alexander.home.packages' --apply 'ps: map (p: p.name) ps' 2>/dev/null > "$S/adult-pkgs-after.json"
diff <(jq -S . "$S/adult-pkgs-before.json") <(jq -S . "$S/adult-pkgs-after.json") && echo "ADULT PKGS UNCHANGED"
```
Expected: both print the "UNCHANGED" line, empty diff. (If Task 0 used the fallback leaves, diff those instead.)

- [ ] **Step 7: Commit**

```bash
git add modules/home/desktops/gnome/default.nix modules/home/desktops/gnome/keybindings.nix modules/home/desktops/gnome/profiles/adult/default.nix
git -c commit.gpgsign=false commit -m "refactor(gnome): extract adult profile from shared base"
```

---

## Task 2: Child profile — minimal desktop + lockdown

**Files:**
- Create: `modules/home/desktops/gnome/profiles/child/default.nix`

- [ ] **Step 1: Create `profiles/child/default.nix`**

```nix
{
  config,
  pkgs,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktops.gnome;
in
{
  config = mkIf (cfg.enable && cfg.profile == "child") {
    # Minimal extension set: user-theme for stylix shell theming, and
    # just-perfection to hide the app-grid button + overview search.
    home.packages = with pkgs; [
      gnomeExtensions.user-themes
      gnomeExtensions.just-perfection
    ];

    # Hide GNOME Settings (Control Center) from the app grid / search.
    xdg.desktopEntries."org.gnome.Settings" = {
      name = "Settings";
      exec = "gnome-control-center";
      noDisplay = true;
    };

    dconf.settings = {
      "org/gnome/shell" = {
        disable-user-extensions = false;
        favorite-apps = map (app: "${app}.desktop") cfg.allowedApps;
        enabled-extensions = [
          "user-theme@gnome-shell-extensions.gcampax.github.com"
          "just-perfection-desktop@just-perfection"
        ];
      };

      # Hide the app grid button and overview search: only the pinned
      # allowedApps (dock) are reachable.
      "org/gnome/shell/extensions/just-perfection" = {
        show-apps-button = false;
        search = false;
      };

      # Lockdown: no Alt+F2 run dialog, no user administration.
      "org/gnome/desktop/lockdown" = {
        disable-command-line = true;
        user-administration-disabled = true;
      };
    };
  };
}
```

- [ ] **Step 2: Format and evaluate the child config**

Run:
```bash
just format modules/home/desktops/gnome/profiles/child
nix eval --json '.#nixosConfigurations.homebook.config.home-manager.users.dima.dconf.settings."org/gnome/shell".enabled-extensions' 2>/dev/null
```
Expected: `"@as ['user-theme@gnome-shell-extensions.gcampax.github.com','just-perfection-desktop@just-perfection']"` — only the two minimal extensions.

- [ ] **Step 3: Assert child has no adult power-user packages**

Run:
```bash
nix eval --json '.#nixosConfigurations.homebook.config.home-manager.users.dima.home.packages' --apply 'ps: map (p: p.name) ps' 2>/dev/null | jq -e 'any(test("dconf-editor|gnome-tweaks|forge|pano|gsconnect|vitals|caffeine")) | not' && echo "CHILD MINIMAL OK"
```
Expected: prints `true` then `CHILD MINIMAL OK` (none of the adult-only packages present).

- [ ] **Step 4: Assert lockdown keys are set**

Run:
```bash
nix eval --json '.#nixosConfigurations.homebook.config.home-manager.users.dima.dconf.settings."org/gnome/desktop/lockdown"' 2>/dev/null
```
Expected: `{"disable-command-line":true,"user-administration-disabled":true}`.

- [ ] **Step 5: Commit**

```bash
git add modules/home/desktops/gnome/profiles/child/default.nix
git -c commit.gpgsign=false commit -m "feat(gnome): minimal locked-down child profile"
```

---

## Task 3: Wire `roles/child` to the new profile

**Files:**
- Modify: `modules/home/roles/child/default.nix:39-47`

- [ ] **Step 1: Replace the `launcher` block**

Change the `desktops.gnome` attribute to:
```nix
      # Minimal, locked-down GNOME: only the allow-listed apps are pinned to the
      # dock; the app grid + search are hidden and system toggles are locked
      # down (see modules/home/desktops/gnome/profiles/child). The allow-list is
      # sourced from enabled app modules rather than hardcoded.
      desktops.gnome = {
        enable = true;
        profile = "child";
        allowedApps =
          optional config.${namespace}.games.minecraft.enable
            config.${namespace}.games.minecraft.desktopId;
      };
```

- [ ] **Step 2: Confirm no stale `launcher` references remain**

Run: `grep -rn "launcher" modules/home/desktops/gnome modules/home/roles/child`
Expected: no output (the `launcher` option is fully gone).

- [ ] **Step 3: Verify the child dock resolves to Minecraft**

Run:
```bash
just format modules/home/roles/child
nix eval --json '.#nixosConfigurations.homebook.config.home-manager.users.dima.dconf.settings."org/gnome/shell".favorite-apps' 2>/dev/null
```
Expected: `"@as ['org.prismlauncher.PrismLauncher.desktop']"`.

- [ ] **Step 4: Commit**

```bash
git add modules/home/roles/child/default.nix
git -c commit.gpgsign=false commit -m "feat(gnome): switch child role to profile = child"
```

---

## Task 4: NixOS polkit — deny wifi/bluetooth toggling for child users

**Files:**
- Create: `modules/nixos/users/child-lockdown/default.nix`

- [ ] **Step 1: Create the polkit lockdown module**

```nix
{
  config,
  lib,
  namespace,
  ...
}:
with lib;
let
  # Users declared with profile = "child" on this host.
  childUsers = attrNames (filterAttrs (_: u: u.profile == "child") config.${namespace}.users);

  # NetworkManager actions that enable/disable networking. Denying these makes
  # the GNOME quick-settings wifi/network toggle refuse for child users, while
  # leaving existing connections up and usable.
  deniedActions = [
    "org.freedesktop.NetworkManager.enable-disable-network"
    "org.freedesktop.NetworkManager.enable-disable-wifi"
    "org.freedesktop.NetworkManager.enable-disable-wwan"
  ];

  userList = concatMapStringsSep " || " (u: ''subject.user == "${u}"'') childUsers;
  actionList = concatMapStringsSep "\n      || " (a: ''action.id == "${a}"'') deniedActions;

  rule = ''
    // Deny network enable/disable for restricted child accounts.
    // Written to a 00- file so it is evaluated before NixOS's 10-nixos.rules
    // (which grants the networkmanager group), and NO short-circuits.
    polkit.addRule(function(action, subject) {
      if ((${userList})
      && (${actionList})) {
        return polkit.Result.NO;
      }
    });
  '';
in
{
  config = mkIf (childUsers != [ ]) {
    environment.etc."polkit-1/rules.d/00-child-network-lockdown.rules".text = rule;
  };
}
```

- [ ] **Step 2: Format and evaluate the generated rule**

Run:
```bash
just format modules/nixos/users/child-lockdown
nix eval --raw '.#nixosConfigurations.homebook.config.environment.etc."polkit-1/rules.d/00-child-network-lockdown.rules".text' 2>/dev/null
```
Expected: JS containing `subject.user == "dima"`, all three `enable-disable-*` action ids, and `polkit.Result.NO`.

- [ ] **Step 3: Confirm the file precedes NixOS's rules**

The filename `00-child-network-lockdown.rules` sorts before `10-nixos.rules`, so polkit evaluates it first and the `NO` wins over the group `YES`. Verify the target path:
```bash
nix eval --raw '.#nixosConfigurations.homebook.config.environment.etc."polkit-1/rules.d/00-child-network-lockdown.rules".target' 2>/dev/null; echo
```
Expected: `polkit-1/rules.d/00-child-network-lockdown.rules`.

- [ ] **Step 4: Commit**

```bash
git add modules/nixos/users/child-lockdown/default.nix
git -c commit.gpgsign=false commit -m "feat(users): polkit deny wifi/network toggling for child accounts"
```

---

## Task 5: Full validation + Bluetooth verification

**Files:** none.

- [ ] **Step 1: Repo checks**

Run: `just check`
Expected: format-check + lint pass (no diffs, no statix/deadnix findings).

- [ ] **Step 2: Build the host closures**

Run: `just build homebook` (or `nix build '.#nixosConfigurations.homebook.config.system.build.toplevel' --no-link 2>&1 | tail -5`)
Expected: builds without error. Confirms both `alexander` and `dima` home-manager generations evaluate and the polkit `etc` file is realised.

- [ ] **Step 3: Final adult-unchanged regression**

Re-run Task 1 Step 6. Expected: still "ADULT DCONF UNCHANGED" / "ADULT PKGS UNCHANGED".

- [ ] **Step 4: Manual runtime verification on `homebook` (post-deploy)**

Deploy to `homebook`, log in as `dima`, and confirm:
- Dock shows only Minecraft; no app-grid button; overview search hidden.
- No dconf-editor / gnome-tweaks installed; Settings absent from the app grid.
- Alt+F2 run dialog does nothing.
- Quick-settings **WiFi** toggle is refused (does not turn off); wifi stays connected.
- **Bluetooth** toggle: check whether the `NO` rule blocks it. Per spec §4.2 the likely outcome is it does **not** — this is the pre-committed accepted fallback (do not disable host Bluetooth; `homebook` is shared with the adult). Record the observed behavior in the PR description.

- [ ] **Step 5: Use the verification skill**

REQUIRED: run the `verify` skill / `superpowers:verification-before-completion` before claiming done — evidence (command output) before assertions.

---

## Done criteria

- [ ] Adult GNOME (`alexander`) dconf + packages provably unchanged (empty diff).
- [ ] Child (`dima`) has only user-theme + just-perfection; no adult power-user tools.
- [ ] Child dconf has lockdown keys and Minecraft-only dock; Settings hidden.
- [ ] `00-child-network-lockdown.rules` denies the three NM actions for `dima`.
- [ ] `just check` + `just build homebook` pass.
- [ ] Runtime behavior on `homebook` verified and recorded (incl. Bluetooth outcome).
