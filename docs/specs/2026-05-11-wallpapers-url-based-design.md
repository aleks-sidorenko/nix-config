# URL-Based Wallpapers Package

## Goal

Refactor `packages/wallpapers/` from a bundle of committed image files into a registry of URL-pinned `fetchurl` derivations, with a new opt-in stylix option for selecting a wallpaper per host, and a Darwin module that actually applies the selected wallpaper on macOS.

## Background

Current state (`master` branch):

- `packages/wallpapers/wallpapers/` holds 20 PNG/JPG files (~31 MB) committed to the repo
- `packages/wallpapers/default.nix` reads the directory and exposes each image as a passthru attribute (e.g., `pkgs.${namespace}.wallpapers.earth`)
- `modules/nixos/styles/stylix/default.nix` and `modules/home/styles/stylix/default.nix` both **hardcode** `image = pkgs.${namespace}.wallpapers.earth`
- The home stylix module sets `stylix.image` in its Darwin branch too, but macOS doesn't apply it — a comment in the file notes "Darwin manages wallpapers separately"
- `modules/home/desktops/hyprland/addons/hyprpaper/default.nix` enables the hyprpaper service but doesn't configure any rotation

Problems:

1. **Repo bloat** — ~31 MB of binary assets when only one wallpaper is used at a time on any host
2. **Inflexible** — changing wallpaper requires editing the stylix module; no per-host override
3. **macOS unused** — wallpaper config exists in the home stylix module's Darwin branch but is a no-op

## Conventions

- **Hash-pinned URLs.** Every wallpaper entry uses `pkgs.fetchurl` with an SRI `hash =` field. Builds are reproducible; only referenced wallpapers are downloaded; Nix caches in `/nix/store`.
- **Hotlink originals.** URLs point to upstream sources (e.g., the canonical Unsplash CDN form `https://images.unsplash.com/photo-<id>?…`). No re-uploads to a host the user controls. If an upstream rots, we replace the entry.
- **Kebab-case names.** Registry keys use lowercase kebab-case (`earth-from-space`, `milky-way-galaxy`). Nix supports hyphenated attribute keys as quoted strings; the `wallpaper = "..."` option accepts arbitrary strings (validated by `types.enum`).
- **Opt-in only.** The new `nix-config.styles.stylix.wallpaper` option defaults to `null`. Hosts that want a wallpaper set it explicitly. When `null`, the stylix module does not set `stylix.image`.

## Design

### Wallpapers package — `packages/wallpapers/default.nix`

Becomes a registry of `pkgs.fetchurl` derivations:

```nix
{ pkgs, lib, ... }:
let
  wallpapers = {
    some-name = pkgs.fetchurl {
      name = "some-name.jpg";
      url  = "https://…";
      hash = "sha256-…";
    };
    # … one entry per wallpaper
  };
in
pkgs.symlinkJoin {
  name = "wallpapers";
  paths = lib.attrValues wallpapers;
  passthru = wallpapers // { names = lib.attrNames wallpapers; };
}
```

**Key properties:**

- Each `wallpapers.<name>` attribute is an independent derivation. Referencing one (e.g., `pkgs.${namespace}.wallpapers.<name>`) realizes only that one file — nothing else is downloaded.
- The top-level `symlinkJoin` keeps `pkgs.${namespace}.wallpapers` usable as a package (matches the shape consumers see today). Currently nothing references the join itself, so realizing the join would only happen if a consumer explicitly asked for all wallpapers — which we don't do.
- `passthru.names` is a list of available wallpaper names, consumed by the `types.enum` constraint in the stylix option.

**Image directory removal:** `packages/wallpapers/wallpapers/` is deleted entirely. The current `installPhase` that copies files into `$out/share/wallpapers` is removed (nothing references that path).

### Migration of existing wallpapers

The current 20 bundled images are not preserved. The new registry starts from a clean slate with user-provided URLs collected during plan preparation. Names are kebab-case identifiers chosen by the user (not derived from prior filenames). The implementation plan is the authoritative source for the initial registry contents; this spec does not enumerate them because the list is expected to evolve via `just wallpaper-add` over time.

### Stylix option — `modules/{nixos,home}/styles/stylix/default.nix`

New option declared in both modules:

```nix
options.${namespace}.styles.stylix = {
  enable = lib.mkEnableOption "Enable stylix style manager";

  wallpaper = lib.mkOption {
    type = lib.types.nullOr (lib.types.enum pkgs.${namespace}.wallpapers.names);
    default = null;
    description = ''
      Name of the wallpaper from the wallpapers registry. When null, no
      wallpaper is applied and stylix.image is not set by this module.
    '';
  };
};
```

Application inside `config`:

```nix
stylix.image = lib.mkIf (cfg.wallpaper != null)
  pkgs.${namespace}.wallpapers.${cfg.wallpaper};
```

**Eval-time safety.** `types.enum pkgs.${namespace}.wallpapers.names` rejects unknown names at eval time with a clear error listing valid names. Typos fail fast instead of producing `attribute missing` deep in stylix.

**`stylix.image` is upstream-required.** When `wallpaper = null`, this module does not set `stylix.image`, so any host that enables stylix without setting wallpaper will fail evaluation with stylix's own error. This is intended — the migration adds an explicit `wallpaper = "<chosen-name>"` to every host that currently relies on the hardcoded default.

### Host migration

Four hosts currently inherit the hardcoded default via the stylix module. Each gets one new line setting the wallpaper to whichever entry is chosen as the default (concrete name fixed in the implementation plan):

```nix
nix-config.styles.stylix.wallpaper = "<chosen-name>";
```

| File | Why it needs the change |
|---|---|
| `homes/aarch64-darwin/oleksandrsy@workbook/default.nix` | Inherits home stylix via `roles.work` → `roles.common` |
| `homes/x86_64-linux/alexander@vm/default.nix` | Inherits home stylix via `roles.common` |
| `homes/x86_64-linux/alexander@desktop/default.nix` | Inherits home stylix via `roles.common` |
| `systems/x86_64-linux/desktop/default.nix` | Inherits nixos stylix via `roles.desktop` |

Hosts can pick a different wallpaper by changing the value to another registry name.

### macOS wallpaper module — `modules/home/desktops/wallpaper/`

New home-manager module (home-manager, not nix-darwin system, because `osascript` runs in the user's GUI session and the image path is already in home-manager scope via `stylix.image`).

```nix
{ lib, pkgs, config, namespace, ... }:
let
  cfg = config.${namespace}.desktops.wallpaper;
in {
  options.${namespace}.desktops.wallpaper.enable =
    lib.mkEnableOption "Apply stylix.image as the desktop wallpaper on macOS";

  config = lib.mkIf
    (cfg.enable && pkgs.stdenv.isDarwin && config.stylix.image != null)
    {
      home.activation.setWallpaper = config.lib.dag.entryAfter [ "writeBoundary" ] ''
        /usr/bin/osascript -e '
          tell application "System Events"
            tell every desktop to set picture to "${config.stylix.image}"
          end tell
        '
      '';
    };
}
```

**Wiring.** The home stylix module's Darwin branch enables it:

```nix
(lib.mkIf pkgs.stdenv.isDarwin {
  ${namespace}.desktops.wallpaper.enable = true;
  # … existing Darwin stylix config (fonts, etc.)
})
```

**Behavior.**

- Runs on every `home-manager switch` / `nh home switch`
- Sets the wallpaper across all desktops/spaces on all monitors (`tell every desktop`)
- No-op when `stylix.image` is unset (i.e., when `wallpaper = null`)
- Disabling the module stops re-applying but does **not** revert macOS to the previous wallpaper

**Known macOS caveats.**

1. **Automation permissions.** On first run, macOS prompts "Allow … to control System Events". User clicks Allow once; the grant persists.
2. **Sonoma+ reboot quirk.** On some macOS 14+ setups, osascript-set wallpapers occasionally revert after a reboot. If observed in practice, swap implementation to `desktoppr` (available as `pkgs.desktoppr` in nixpkgs) — option preserved for follow-up, not implemented in v1.
3. **Per-monitor differentiation.** Not supported in v1; the same wallpaper is applied to every desktop. If per-monitor support is wanted later, extend the module to iterate over monitors.

### Justfile recipes

Two new recipes under the `wallpaper-*` namespace prefix (matches `bootstrap-*`, `router-*`, `secrets-*`):

**`wallpaper-add <name> <url>`** — runs `nix-prefetch-url` against the URL, converts the result to SRI, and prints a paste-ready `fetchurl` block (including the required `name = "<name>.jpg";` attribute). Does not auto-mutate the Nix file; output goes to stdout for human review and copy-paste, matching the explicit-state pattern used by `bootstrap-secrets`.

**`wallpaper-list`** — prints `pkgs.${namespace}.wallpapers.names` (resolved for the current `builtins.currentSystem`) one per line.

Concrete recipe bodies live in the implementation plan.

## Files Touched

**Created:**

- `modules/home/desktops/wallpaper/default.nix` — Darwin wallpaper activation module

**Modified:**

- `packages/wallpapers/default.nix` — replaced with URL-based registry
- `modules/nixos/styles/stylix/default.nix` — adds `wallpaper` option, conditional `stylix.image`
- `modules/home/styles/stylix/default.nix` — adds `wallpaper` option, conditional `stylix.image`, enables wallpaper module in Darwin branch
- `homes/aarch64-darwin/oleksandrsy@workbook/default.nix` — sets `nix-config.styles.stylix.wallpaper = "<chosen-name>";`
- `homes/x86_64-linux/alexander@vm/default.nix` — sets `nix-config.styles.stylix.wallpaper = "<chosen-name>";`
- `homes/x86_64-linux/alexander@desktop/default.nix` — sets `nix-config.styles.stylix.wallpaper = "<chosen-name>";`
- `systems/x86_64-linux/desktop/default.nix` — sets `nix-config.styles.stylix.wallpaper = "<chosen-name>";`
- `justfile` — adds `wallpaper-add` and `wallpaper-list` recipes

**Deleted:**

- `packages/wallpapers/wallpapers/` — directory of 20 committed images

## Non-goals

- **Runtime wallpaper rotation / carousel.** "Dynamic" in this design means easy switch at build time (change one line, rebuild). Timer-based rotation (systemd timer, launchd) is out of scope.
- **Time-of-day / theme-aware switching.** Not implemented.
- **Per-monitor wallpapers on macOS.** Same image on every desktop. (Linux Hyprland already supports per-monitor via hyprpaper; out of scope to change.)
- **Stylix color derivation from images.** Color scheme stays explicit via `base16Scheme = "catppuccin-mocha.yaml"` (already the case). Stylix uses `image` only as the visible desktop image.
- **Wallpaper rollback on disable.** Disabling the macOS module stops re-applying but does not restore the previous wallpaper.

## Open Items

- **URL list** — collected by the user during plan preparation (per Q5 = 5a). Concrete registry contents live in the implementation plan and may grow over time via `just wallpaper-add`.
- **Sonoma reboot quirk** — if observed in practice after rollout, follow-up swaps osascript implementation for `desktoppr`.
