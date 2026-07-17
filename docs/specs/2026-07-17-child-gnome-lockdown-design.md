# Design: parent/child GNOME split + child UI lockdown

- **Date**: 2026-07-17
- **Status**: Approved (design); pending spec-review + implementation plan
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
  default.nix          # base + `profile` option; user-agnostic infra only
  monitors.nix         # shared, unchanged (gated on enable)
  profiles/
    adult.nix          # today's power-user setup (extensions, keybindings, vitals, tray)
    child.nix          # minimal desktop + lockdown dconf + restricted dock
```

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
- The `keybindings.nix` content moves under the **adult** profile (see below);
  the base defines no keybindings.

**`profiles/adult.nix` (`mkIf enable && profile == "adult"`)** = current behavior
**verbatim**, so `alexander@homebook` / `alexander@desktop` are unchanged:
- Full extension package list incl. `dconf-editor`, `gnome-tweaks`.
- Full `enabled-extensions`, `favorite-apps = nautilus ++ favoriteApps`,
  appindicator tray (`legacy-tray-enabled`), vitals config.
- All of today's `keybindings.nix` (forge tiling, workspaces, media keys,
  terminal, power menu, screenshots).

**`profiles/child.nix` (`mkIf enable && profile == "child"`)** = minimal + locked:
- Packages: **only** `gnomeExtensions.just-perfection` (needed to hide grid +
  search) and `gnomeExtensions.user-themes` (stylix). **No** dconf-editor,
  gnome-tweaks, forge, pano, gsconnect, caffeine, vitals, hibernate, launch-new-instance.
- `enabled-extensions = [ user-theme just-perfection ]`.
- `favorite-apps = map (a: "${a}.desktop") cfg.allowedApps` (Minecraft; data-driven).
- `just-perfection` = `{ show-apps-button = false; search = false; }`.
- **Lockdown dconf** `org/gnome/desktop/lockdown`:
  - `disable-command-line = true` (kills Alt+F2 run dialog),
  - `user-administration-disabled = true`.
- **Hide Settings**: `xdg.desktopEntries."org.gnome.Settings"` (or an
  `xdg.dataFile` override) with `noDisplay = true` so Control Center is not in
  the app grid/search.
- No terminal keybinding, no tiling. Keybindings minimal / GNOME defaults.

### 4.2 System-level polkit lockdown (WiFi/Bluetooth)

A NixOS module co-located with the users concept (new
`modules/nixos/users/child-lockdown/default.nix`, or a sibling imported by the
users module). It:

- Derives the child usernames from config:
  `childUsers = attrNames (filterAttrs (_: u: u.profile == "child") config.${ns}.users)`.
- Emits, for each child user, a `security.polkit` rule returning
  `polkit.Result.NO` (denied outright — no auth prompt, toggle silently fails)
  for the NetworkManager enable/disable actions:
  - `org.freedesktop.NetworkManager.enable-disable-network`
  - `org.freedesktop.NetworkManager.enable-disable-wifi`
  - `org.freedesktop.NetworkManager.enable-disable-wwan`
- An explicit `NO` overrides the `networkmanager`-group allow, so WiFi stays
  connected and functional but the child cannot turn it (or the whole network)
  off. No group changes needed.
- Gated on `childUsers != []` so hosts without a child are untouched.

**Bluetooth (best-effort, open item).** BlueZ does not polkit-gate the adapter
power toggle as cleanly as NetworkManager, so a `NO` rule may not fully block the
quick-settings BT toggle. Plan: add the analogous rule for any applicable BlueZ
action and **verify on the running `homebook`** during implementation. If it does
not take effect, fall back to one of (decide at that point): (a) accept it (a
child toggling Bluetooth is low-risk), or (b) if the family doesn't use Bluetooth
on that laptop, disable the host Bluetooth service. This is explicitly flagged
rather than overclaimed.

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
- **Bluetooth** blocking is best-effort (see §4.2).

## 6. Affected files

- `modules/home/desktops/gnome/default.nix` — reduce to base + `profile`/`allowedApps` options.
- `modules/home/desktops/gnome/profiles/adult.nix` — **new**; today's setup verbatim (incl. moved keybindings).
- `modules/home/desktops/gnome/profiles/child.nix` — **new**; minimal + lockdown.
- `modules/home/desktops/gnome/keybindings.nix` — moved into / gated to adult profile.
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
