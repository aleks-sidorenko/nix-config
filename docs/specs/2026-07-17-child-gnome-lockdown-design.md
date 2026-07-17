# Design: parent/child GNOME split + child UI lockdown

- **Date**: 2026-07-17
- **Status**: Approved (design); spec-review complete (1 blocker + should-fixes folded in)
- **Scope**: Stop the `child` profile from inheriting the full adult power-user
  GNOME. Refactor the home-manager GNOME module into a shared hardware/infra
  **base** plus per-**profile** layers (`adult` / `child`), give the child a
  minimal locked-down desktop, and prevent the child from toggling
  WiFi/Bluetooth from the UI via a system-level polkit rule.

## 1. Goals

1. **Minimal child desktop.** The child (`dima@homebook`) gets a stripped GNOME:
   no clipboard history, tiling WM, phone integration, system monitor, hibernate
   button, dconf-editor, or gnome-tweaks. Only what a Minecraft-only account
   needs.
2. **Minimal possibility of changes from the UI.** The child cannot:
   - toggle WiFi/Bluetooth on/off (they stay on and working),
   - reach GNOME Settings from the app grid/search,
   - run arbitrary commands (Alt+F2), perform user administration, or use
     dconf-editor/tweaks to undo the above.
3. **Decouple parent from child** so the two setups stop complicating each
   other. Adult (`alexander`) behavior is **unchanged**.

## 2. Non-goals

- No content filtering, time limits, or web filtering (YAGNI — layer later).
- No *hard* dconf locking via system dconf profile/lock files. Combined with no
  dconf-editor/tweaks/terminal, a child realistically cannot change dconf; hard
  locks are a possible later stretch.
- No changes to darwin or to non-GNOME desktops.

## 3. Background — current state

- **Home GNOME module** `modules/home/desktops/gnome/`:
  - `default.nix` — options (`enable`, `favoriteApps`, `launcher.{restrict,allowedApps}`)
    and *all* dconf + the full extension package list, including `dconf-editor`
    and `gnome-tweaks` (`default.nix:47-48`), installed for **every** GNOME user.
  - `enabled-extensions` (`default.nix:105-119`) is the **same for adult and
    child** — forge, pano, gsconnect, caffeine, vitals, appindicator — plus
    `just-perfection` only when `restrict` is true.
  - `keybindings.nix` — adult power-user bindings (forge tiling on Super+hjkl, 10
    static workspaces, Super+T terminal, Alt+F2 run dialog).
  - `monitors.nix` — generates `~/.config/monitors.xml` from
    `nix-config.desktops.monitors`; hardware-driven, user-agnostic.
  - `addons/default.nix` — pavucontrol, disk-utility, calculator, xdg/mime, gtk.
  - The only child-specific behavior is the `launcher.restrict` conditional
    (`default.nix:99-103,152-159`): pins only `allowedApps` to the dock and hides
    the app-grid button + overview search via `just-perfection`.
- **Child wiring** `modules/home/roles/child/default.nix:39-47`: enables GNOME
  directly with `launcher = { restrict = true; allowedApps = <minecraft>; }`.
  Deliberately avoids `roles.graphical` (no browser/teamviewer/media).
- **Users module** `modules/nixos/users/default.nix`: declares all accounts;
  `profile` enum `adult|child` (`:27-31`); child never gets `wheel` (no sudo),
  gets `childGroups = [audio video input]`. Everyone (incl. child) is in the
  `networkmanager` base group (`:38-42`). Child usernames are derivable via
  `filterAttrs (_: u: u.profile == "child") config.${ns}.users`.
- **No lockdown** exists anywhere today: no `org/gnome/desktop/lockdown`, no
  polkit restrictions beyond no-sudo.
- **Mechanism fact**: GNOME quick-settings WiFi/Bluetooth toggles are gated by
  polkit/NetworkManager, **not** dconf. `just-perfection` can hide the *entire*
  quick-settings menu but **not** individual tiles, so per-tile UI hiding would
  require an extra dedicated extension (rejected — cuts against "minimal").

## 4. Design

### 4.1 Home-manager GNOME refactor → base + profiles

Restructure `modules/home/desktops/gnome/`:

```
modules/home/desktops/gnome/
  default.nix              # base + `profile` option; user-agnostic infra only
  keybindings.nix          # kept top-level; re-gated to profile == "adult" (see below)
  monitors.nix             # shared, unchanged (gated on enable)
  addons/default.nix       # unchanged
  profiles/
    adult/default.nix      # today's extensions/tray/vitals/dock
    child/default.nix      # minimal desktop + lockdown dconf + restricted dock
```

**Module discovery (critical).** `default.nix:14` imports siblings via
`lib.snowfall.fs.get-non-default-nix-files ./.`, which is **non-recursive** and
only returns top-level non-`default.nix` files. It will **not** pick up files in
a `profiles/` subdir. Therefore the profile layers use `profiles/<x>/default.nix`
so snowfall's own module auto-discovery (`get-default-nix-files-recursive`, which
matches every `default.nix`) evaluates them as independent home modules — the
exact proven pattern already used by `addons/default.nix`. Each is always loaded
and gates its own `config` block on `cfg.profile`. A flat `profiles/adult.nix`
would be a dead file — do **not** use that layout.

**`default.nix` (base, `mkIf enable`)** keeps only what both profiles share:
- New option `nix-config.desktops.gnome.profile` = `enum ["adult" "child"]`,
  default `"adult"`.
- Keep `favoriteApps` (adult dock). Add `allowedApps` (child dock allow-list),
  replacing `launcher.{restrict,allowedApps}` — `restrict` is now implied by
  `profile == "child"`.
- Retain: `stylix.targets.gnome`, `desktops.addons` (gtk/xdg/nautilus) +
  `gnome.addons`, `org/gnome/desktop/input-sources` (locale layouts),
  `enable-hot-corners = false`, power/idle/hibernate timeouts, xdg portals,
  ssh-agent workaround (`GSM_SKIP_SSH_AGENT_WORKAROUND` + autostart override),
  `kdeconnect` force-off.
- `monitors.nix` unchanged.
- `keybindings.nix` stays a **top-level** sibling (still imported by the existing
  non-recursive `imports`), but its guard changes from `mkIf cfg.enable`
  (`keybindings.nix:13`) to `mkIf (cfg.enable && cfg.profile == "adult")`. This
  keeps the adult power-user bindings working without moving the file (and avoids
  the discovery pitfall above). The base defines no keybindings.

**`profiles/adult/default.nix` (`mkIf (cfg.enable && cfg.profile == "adult")`)** =
current behavior **verbatim**, so `alexander@homebook` / `alexander@desktop` are
unchanged (adult homes never set `profile`, so the `"adult"` default applies):
- Full extension package list incl. `dconf-editor`, `gnome-tweaks`.
- Full `enabled-extensions`, `favorite-apps = nautilus ++ favoriteApps`,
  appindicator tray (`legacy-tray-enabled`), vitals config.
- (Keybindings remain in the re-gated top-level `keybindings.nix`, not here.)

**`profiles/child/default.nix` (`mkIf (cfg.enable && cfg.profile == "child")`)** =
minimal + locked:
- Packages: **only** `gnomeExtensions.just-perfection` (needed to hide grid +
  search) and `gnomeExtensions.user-themes` (optional — enables GNOME Shell
  theming so stylix styles the shell; included for visual consistency). **No**
  dconf-editor, gnome-tweaks, forge, pano, gsconnect, caffeine, vitals,
  hibernate, launch-new-instance.
- `enabled-extensions = [ user-theme just-perfection ]`.
- `favorite-apps = map (a: "${a}.desktop") cfg.allowedApps` (Minecraft; data-driven).
- `just-perfection` = `{ show-apps-button = false; search = false; }`.
- **Lockdown dconf** `org/gnome/desktop/lockdown`:
  - `disable-command-line = true` (kills Alt+F2 run dialog),
  - `user-administration-disabled = true`.
- **Hide Settings**: `xdg.desktopEntries."org.gnome.Settings"` with
  `noDisplay = true` so Control Center is not in the app grid/search. Note the
  generated entry still requires `name` (and realistically `exec`) fields — supply
  them; `noDisplay` alone is not a complete entry.
- No terminal keybinding, no tiling. Keybindings minimal / GNOME defaults.

**dconf merge hazard (implementation note).** Several top-level dconf paths are
contributed by more than one file and rely on home-manager merging *disjoint*
subkeys: `org/gnome/mutter` (`monitors.nix:14` `experimental-features` +
`keybindings.nix:161` `dynamic-workspaces`) and `org/gnome/desktop/wm/preferences`
(`default.nix:92` `focus-mode` + `keybindings.nix:165` `num-workspaces`). When
splitting, never set the **same** subkey under one path from both the base and a
profile — home-manager throws a conflicting-definition error. Keep subkeys
disjoint across base/profile files.

### 4.2 System-level polkit lockdown (WiFi/Bluetooth)

A NixOS module co-located with the users concept (new
`modules/nixos/users/child-lockdown/default.nix`, or a sibling imported by the
users module). It:

- Derives the child usernames from config:
  `childUsers = attrNames (filterAttrs (_: u: u.profile == "child") config.${ns}.users)`.
- Emits, for each child user, a polkit rule returning `polkit.Result.NO`
  (denied outright — no auth prompt, toggle silently fails) for the
  NetworkManager enable/disable actions:
  - `org.freedesktop.NetworkManager.enable-disable-network`
  - `org.freedesktop.NetworkManager.enable-disable-wifi`
  - `org.freedesktop.NetworkManager.enable-disable-wwan`
- **Ordering matters.** NixOS already emits a `networkmanager`-group **YES** rule
  (verified in `config.security.polkit.extraConfig`) and NetworkManager's upstream
  policy also allows active local sessions by default. polkit evaluates
  `rules.d/*` in lexical filename order and stops at the **first** definitive
  result. `security.polkit.extraConfig` lands in `10-nixos.rules` with no
  guaranteed ordering vs. the group YES rule, so it is **not** reliable. The deny
  is therefore written to its own lower-numbered file via
  `environment.etc."polkit-1/rules.d/00-child-network-lockdown.rules"`, which is
  evaluated before `10-nixos.rules` and wins. WiFi stays connected and functional;
  the child simply cannot turn it (or the whole network) off. No group changes.
- Gated on `childUsers != []` so hosts without a child are untouched.

**Bluetooth (best-effort, fallback pre-committed).** BlueZ does not polkit-gate
the adapter power toggle the way NetworkManager gates its actions (the GNOME BT
toggle largely goes through rfkill/BlueZ D-Bus with no denyable action for a
local active session), so a `NO` rule likely will **not** block the quick-settings
BT toggle. Plan: add the analogous rule and **verify on `homebook`**. Realistic
outcome: it doesn't take effect. **Committed fallback: accept it** — a child
toggling Bluetooth is low-risk, and the obvious hard block (disabling
`hardware.bluetooth` host-wide) is rejected because `homebook` is a *shared*
laptop and that would also break Bluetooth for the adult, violating the
"adult unchanged" goal. If a hard per-child block is ever required, it belongs in
a future stretch (e.g. a login-session rfkill guard), not this change.

### 4.3 Wiring

`modules/home/roles/child/default.nix` changes:

```nix
desktops.gnome = {
  enable = true;
  profile = "child";
  allowedApps =
    optional config.${ns}.games.minecraft.enable
      config.${ns}.games.minecraft.desktopId;
};
```

No other homes or hosts change.

## 5. Caveats (documented, accepted)

- **Settings gear in quick-settings** still launches Control Center even with the
  `.desktop` hidden. Acceptable: privileged panels are already polkit/no-sudo
  gated (the child can look but not change), and WiFi specifically is blocked by
  §4.2. Defense-in-depth, not a hard block.
- **dconf is not hard-locked.** Enforcement relies on removing the tools
  (dconf-editor/tweaks) and access (no terminal, no sudo). Sufficient for a
  child; hard system-dconf locks are a later option.
- **Bluetooth** blocking is best-effort; committed fallback is to accept child
  toggling rather than degrade the shared adult experience (see §4.2).

## 6. Affected files

- `modules/home/desktops/gnome/default.nix` — reduce to base + `profile`/`allowedApps` options.
- `modules/home/desktops/gnome/profiles/adult/default.nix` — **new**; today's extensions/tray/vitals/dock verbatim.
- `modules/home/desktops/gnome/profiles/child/default.nix` — **new**; minimal + lockdown.
- `modules/home/desktops/gnome/keybindings.nix` — kept top-level; guard re-gated to `profile == "adult"`.
- `modules/home/desktops/gnome/monitors.nix`, `addons/default.nix` — unchanged.
- `modules/home/roles/child/default.nix` — switch to `profile = "child"`.
- `modules/nixos/users/child-lockdown/default.nix` — **new**; polkit rules for child users.

## 7. Verification

- `just check` + `just build` (or `nh` on `homebook`).
- Adult: confirm `alexander@homebook`/`@desktop` GNOME is byte-identical in
  behavior (extensions, keybindings, dock, vitals) — diff `nix eval` of dconf
  where practical, or manual smoke test.
- Child on `homebook`: dock shows only Minecraft; app grid + search hidden; no
  dconf-editor/tweaks installed; Alt+F2 dead; Settings absent from grid; WiFi
  toggle refused (wifi stays connected); Bluetooth per §4.2 outcome.
