# URL-Based Wallpapers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the bundled-images wallpapers package with a registry of URL-pinned `fetchurl` derivations, add an opt-in `nix-config.styles.stylix.wallpaper` option, migrate the 4 hosts currently relying on the hardcoded `earth` default, and apply the selected wallpaper on macOS via `osascript` at home-manager activation.

**Architecture:** `packages/wallpapers/default.nix` becomes a registry whose values are independent `fetchurl` derivations — Nix only realizes (downloads) the entry actually referenced. Stylix modules expose a `wallpaper = "<name>"` option (defaulting to `null`, eval-checked via `types.enum`); when set, `stylix.image` is wired to the corresponding registry entry. A new home-manager module `modules/home/desktops/wallpaper/` runs `osascript` from `home.activation` to apply `stylix.image` as the macOS desktop picture.

**Tech Stack:** Nix (snowfall-lib namespace `nix-config`), `pkgs.fetchurl`, `pkgs.symlinkJoin`, stylix, home-manager activation scripts, `osascript`, `just`.

**Prerequisites:**
- Working on branch `feat/wallpapers-url-based` (already created)
- Spec: `docs/specs/2026-05-11-wallpapers-url-based-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `packages/wallpapers/default.nix` | Modify (rewrite) | Registry of fetchurl entries; exposes per-name passthru + `names` list |
| `packages/wallpapers/wallpapers/` | Delete | Old bundled-image directory (20 files, ~31MB) |
| `modules/nixos/styles/stylix/default.nix` | Modify | Add `wallpaper` option; conditional `stylix.image` |
| `modules/home/styles/stylix/default.nix` | Modify | Add `wallpaper` option; conditional `stylix.image`; enable Darwin wallpaper module |
| `modules/home/desktops/wallpaper/default.nix` | Create | Apply `stylix.image` as macOS desktop picture via osascript |
| `systems/x86_64-linux/desktop/default.nix` | Modify | Set wallpaper explicitly (NixOS desktop host) |
| `homes/aarch64-darwin/oleksandrsy@workbook/default.nix` | Modify | Set wallpaper explicitly (workbook home) |
| `homes/x86_64-linux/alexander@vm/default.nix` | Modify | Set wallpaper explicitly (vm home) |
| `homes/x86_64-linux/alexander@desktop/default.nix` | Modify | Set wallpaper explicitly (desktop home) |
| `justfile` | Modify | Add `wallpaper-add` and `wallpaper-list` recipes |

---

## Wallpaper registry contents

Three entries collected during brainstorming. URL is the canonical Unsplash CDN form (no `/download` redirect dance); `name = "..."` is required on `fetchurl` because the URL contains `&` query separators that would otherwise produce an invalid store path.

```nix
{
  green-plains-on-mountain = pkgs.fetchurl {
    name = "green-plains-on-mountain.jpg";
    url  = "https://images.unsplash.com/photo-1547285629-6cab32b3dfdb?ixlib=rb-4.1.0&q=85&fm=jpg&crop=entropy&cs=srgb&dl=med-nadjib-ramdane-yg9fwePu9Og-unsplash.jpg&w=1920";
    hash = "sha256-JHbmgI3HtDAek6MCLs9j6P4ATsgHt4JWJTD6Qhi0jbk=";
  };

  the-sun-shines-through-the-fog-in-the-mountains = pkgs.fetchurl {
    name = "the-sun-shines-through-the-fog-in-the-mountains.jpg";
    url  = "https://images.unsplash.com/photo-1654169761064-95b4c1e2be6e?ixlib=rb-4.1.0&q=85&fm=jpg&crop=entropy&cs=srgb&dl=rob-bates-4He7i9d-Uyw-unsplash.jpg&w=1920";
    hash = "sha256-OBigjxIJ6ixKzYZ+xfpLRRlj34qU+mu6JdYGcZEC+Fg=";
  };

  sun-light-passing-through-green-leafed-tree = pkgs.fetchurl {
    name = "sun-light-passing-through-green-leafed-tree.jpg";
    url  = "https://images.unsplash.com/photo-1518495973542-4542c06a5843?ixlib=rb-4.1.0&q=85&fm=jpg&crop=entropy&cs=srgb&dl=jeremy-bishop-EwKXn5CapA4-unsplash.jpg&w=1920";
    hash = "sha256-C7VUTpShF2LhQwVfZAcVnAQJDHuASr4VHqAV7ZlHcDc=";
  };
}
```

All 4 migration hosts default to `green-plains-on-mountain`.

---

## Task 1: URL-based registry, stylix option, host migration (atomic)

This task is one commit because the steps are interdependent: removing the bundled images while keeping the hardcoded `pkgs.${namespace}.wallpapers.earth` reference in the stylix modules would break eval. All eight files change together.

**Files:**
- Modify (rewrite): `packages/wallpapers/default.nix`
- Delete: `packages/wallpapers/wallpapers/` (entire directory)
- Modify: `modules/nixos/styles/stylix/default.nix`
- Modify: `modules/home/styles/stylix/default.nix`
- Modify: `systems/x86_64-linux/desktop/default.nix`
- Modify: `homes/aarch64-darwin/oleksandrsy@workbook/default.nix`
- Modify: `homes/x86_64-linux/alexander@vm/default.nix`
- Modify: `homes/x86_64-linux/alexander@desktop/default.nix`

- [ ] **Step 1: Replace `packages/wallpapers/default.nix`**

Write the file with this exact content:

```nix
{
  pkgs,
  lib,
  ...
}:
let
  wallpapers = {
    green-plains-on-mountain = pkgs.fetchurl {
      name = "green-plains-on-mountain.jpg";
      url  = "https://images.unsplash.com/photo-1547285629-6cab32b3dfdb?ixlib=rb-4.1.0&q=85&fm=jpg&crop=entropy&cs=srgb&dl=med-nadjib-ramdane-yg9fwePu9Og-unsplash.jpg&w=1920";
      hash = "sha256-JHbmgI3HtDAek6MCLs9j6P4ATsgHt4JWJTD6Qhi0jbk=";
    };

    the-sun-shines-through-the-fog-in-the-mountains = pkgs.fetchurl {
      name = "the-sun-shines-through-the-fog-in-the-mountains.jpg";
      url  = "https://images.unsplash.com/photo-1654169761064-95b4c1e2be6e?ixlib=rb-4.1.0&q=85&fm=jpg&crop=entropy&cs=srgb&dl=rob-bates-4He7i9d-Uyw-unsplash.jpg&w=1920";
      hash = "sha256-OBigjxIJ6ixKzYZ+xfpLRRlj34qU+mu6JdYGcZEC+Fg=";
    };

    sun-light-passing-through-green-leafed-tree = pkgs.fetchurl {
      name = "sun-light-passing-through-green-leafed-tree.jpg";
      url  = "https://images.unsplash.com/photo-1518495973542-4542c06a5843?ixlib=rb-4.1.0&q=85&fm=jpg&crop=entropy&cs=srgb&dl=jeremy-bishop-EwKXn5CapA4-unsplash.jpg&w=1920";
      hash = "sha256-C7VUTpShF2LhQwVfZAcVnAQJDHuASr4VHqAV7ZlHcDc=";
    };
  };
in
pkgs.symlinkJoin {
  name = "wallpapers";
  paths = lib.attrValues wallpapers;
  passthru = wallpapers // {
    names = lib.attrNames wallpapers;
  };
}
```

Notes:
- `passthru = wallpapers // { names = ...; }` exposes each entry as a passthru attribute on the joined package, so existing access patterns (`pkgs.${namespace}.wallpapers.green-plains-on-mountain`) work.
- `passthru.names` is consumed by the `types.enum` constraint in step 3.

- [ ] **Step 2: Delete the old image directory**

```bash
git -C /Users/oleksandrsy/.nix-config rm -r packages/wallpapers/wallpapers
```

- [ ] **Step 3: Modify `modules/nixos/styles/stylix/default.nix`**

Find the option block (currently only `enable`) and add the `wallpaper` option. Find the hardcoded `image = pkgs.${namespace}.wallpapers.earth;` and replace with the conditional form.

Resulting structure:

```nix
options.${namespace}.styles.stylix = {
  enable = lib.mkEnableOption "Enable stylix theme management on the system level";

  wallpaper = lib.mkOption {
    type = lib.types.nullOr (lib.types.enum pkgs.${namespace}.wallpapers.names);
    default = null;
    description = ''
      Name of the wallpaper from the wallpapers registry. When null,
      stylix.image is not set by this module.
    '';
  };
};

config = lib.mkIf cfg.enable {
  stylix = {
    enable = true;
    autoEnable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    homeManagerIntegration.autoImport = false;
    homeManagerIntegration.followSystem = false;

    image = lib.mkIf (cfg.wallpaper != null)
      pkgs.${namespace}.wallpapers.${cfg.wallpaper};

    # ... cursor, fonts (unchanged)
  };
};
```

- [ ] **Step 4: Modify `modules/home/styles/stylix/default.nix`**

Add the same `wallpaper` option to the options block, and replace both `image = pkgs.${namespace}.wallpapers.earth;` lines (one in the Linux branch, one in the Darwin branch) with the conditional form:

```nix
options.${namespace}.styles.stylix = {
  enable = lib.mkEnableOption "Enable stylix style manager";

  wallpaper = lib.mkOption {
    type = lib.types.nullOr (lib.types.enum pkgs.${namespace}.wallpapers.names);
    default = null;
    description = ''
      Name of the wallpaper from the wallpapers registry. When null,
      stylix.image is not set by this module.
    '';
  };
};
```

In both `lib.mkIf pkgs.stdenv.isLinux { stylix = { ... }; }` and `lib.mkIf pkgs.stdenv.isDarwin { stylix = { ... }; }` blocks, replace:

```nix
image = pkgs.${namespace}.wallpapers.earth;
```

with:

```nix
image = lib.mkIf (cfg.wallpaper != null)
  pkgs.${namespace}.wallpapers.${cfg.wallpaper};
```

Keep everything else in these blocks (autoEnable, base16Scheme, iconTheme, cursor, fonts, stylix.targets) unchanged.

- [ ] **Step 5: Migrate `systems/x86_64-linux/desktop/default.nix`**

Add inside the `nix-config = { ... }` block:

```nix
styles.stylix.wallpaper = "green-plains-on-mountain";
```

- [ ] **Step 6: Migrate `homes/aarch64-darwin/oleksandrsy@workbook/default.nix`**

Add inside the `nix-config = { ... }` block:

```nix
styles.stylix.wallpaper = "green-plains-on-mountain";
```

- [ ] **Step 7: Migrate `homes/x86_64-linux/alexander@vm/default.nix`**

Add inside the `nix-config = { ... }` block:

```nix
styles.stylix.wallpaper = "green-plains-on-mountain";
```

- [ ] **Step 8: Migrate `homes/x86_64-linux/alexander@desktop/default.nix`**

Add inside the `nix-config = { ... }` block:

```nix
styles.stylix.wallpaper = "green-plains-on-mountain";
```

- [ ] **Step 9: Format and verify eval**

```bash
just format
just check
```

Expected: both succeed. `just check` runs format-check + statix + deadnix.

- [ ] **Step 10: Verify registry resolves**

```bash
nix eval --json '.#packages.x86_64-linux.wallpapers.names'
```

Expected output (as JSON array):

```json
["green-plains-on-mountain","sun-light-passing-through-green-leafed-tree","the-sun-shines-through-the-fog-in-the-mountains"]
```

- [ ] **Step 11: Verify a single entry can be realized**

```bash
nix build --no-link '.#packages.x86_64-linux.wallpapers.green-plains-on-mountain'
```

Expected: downloads the image (visible network activity on first run) and exits cleanly. Run again — should be instant (cached).

- [ ] **Step 12: Verify a representative host evaluates**

```bash
nix flake check --no-build
```

Expected: passes. (`--no-build` skips the actual derivation builds; we only need to confirm evaluation, not realize every config.)

If flake-check is too slow/heavy, fall back to evaluating one host directly:

```bash
nix eval '.#nixosConfigurations.desktop.config.stylix.image' --raw
```

Expected: prints a `/nix/store/...` path ending in `green-plains-on-mountain.jpg`.

- [ ] **Step 13: Verify typo behavior (negative test)**

Temporarily change one host's wallpaper to `"green-plains-on-mountainz"` (typo). Re-run `nix flake check`. Expected: eval fails with a clear error listing the three valid names. Revert the typo before continuing.

- [ ] **Step 14: Commit**

```bash
git -C /Users/oleksandrsy/.nix-config add packages/wallpapers modules/nixos/styles/stylix modules/home/styles/stylix systems/x86_64-linux/desktop/default.nix 'homes/aarch64-darwin/oleksandrsy@workbook/default.nix' 'homes/x86_64-linux/alexander@vm/default.nix' 'homes/x86_64-linux/alexander@desktop/default.nix'
git -C /Users/oleksandrsy/.nix-config commit -m "$(cat <<'EOF'
feat(wallpapers): switch to URL-pinned registry with opt-in stylix selection

Replace ~31MB of bundled images in packages/wallpapers/wallpapers/ with a
registry of three pkgs.fetchurl entries (hash-pinned Unsplash CDN URLs).
Only referenced wallpapers are downloaded; nothing else is fetched.

Add nix-config.styles.stylix.wallpaper option to both stylix modules
(nullOr enum of registry names, default null). Hosts that previously
inherited the hardcoded earth wallpaper now set the option explicitly.
EOF
)"
```

---

## Task 2: macOS wallpaper application

**Files:**
- Create: `modules/home/desktops/wallpaper/default.nix`
- Modify: `modules/home/styles/stylix/default.nix` (wire the module in the Darwin branch)

- [ ] **Step 1: Create `modules/home/desktops/wallpaper/default.nix`**

```nix
{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.desktops.wallpaper;
in
{
  options.${namespace}.desktops.wallpaper = {
    enable = lib.mkEnableOption "Apply stylix.image as the desktop wallpaper on macOS";
  };

  config = lib.mkIf (cfg.enable && pkgs.stdenv.isDarwin && config.stylix.image != null) {
    home.activation.setWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      /usr/bin/osascript -e '
        tell application "System Events"
          tell every desktop to set picture to "${config.stylix.image}"
        end tell
      '
    '';
  };
}
```

- [ ] **Step 2: Wire the module in `modules/home/styles/stylix/default.nix`**

Inside the `(lib.mkIf pkgs.stdenv.isDarwin { ... })` block, add a sibling attribute next to `stylix` and `stylix.targets`:

```nix
(lib.mkIf pkgs.stdenv.isDarwin {
  stylix = {
    # ... existing ...
  };

  stylix.targets = {
    # ... existing ...
  };

  ${namespace}.desktops.wallpaper.enable = true;
})
```

- [ ] **Step 3: Format and verify eval**

```bash
just format
just check
nix eval '.#homeConfigurations."oleksandrsy@workbook".config.home.activation.setWallpaper' --raw
```

Expected: format/check pass; the eval prints a non-empty activation script string containing `osascript` and the resolved `/nix/store/.../green-plains-on-mountain.jpg` path.

- [ ] **Step 4: Apply on workbook (the only Darwin host) and observe**

This step is a manual verification on a Mac. If running the executor on a non-Mac, skip and instead read the activation script content to confirm it looks right.

```bash
nh home switch
```

Expected: home-manager activation runs; macOS may prompt for "Allow … to control System Events" on first run (click Allow). Wallpaper changes on all monitors/desktops.

If macOS does not prompt and the wallpaper does not change, run the inner command manually to diagnose:

```bash
osascript -e 'tell application "System Events" to tell every desktop to set picture to "/nix/store/.../green-plains-on-mountain.jpg"'
```

A permission error here means Automation permissions need to be granted in System Settings → Privacy & Security → Automation.

- [ ] **Step 5: Commit**

```bash
git -C /Users/oleksandrsy/.nix-config add modules/home/desktops/wallpaper modules/home/styles/stylix/default.nix
git -C /Users/oleksandrsy/.nix-config commit -m "$(cat <<'EOF'
feat(home/desktops/wallpaper): apply wallpaper on macOS via osascript

Adds a home-manager module that runs osascript at activation to set
stylix.image as the desktop picture on every Mac desktop/space. Wired
into the Darwin branch of the stylix module so it activates automatically
on hosts that have stylix and a wallpaper configured. No-op when
stylix.image is unset.
EOF
)"
```

---

## Task 3: justfile recipes

**Files:**
- Modify: `justfile`

- [ ] **Step 1: Append `wallpaper-add` recipe**

Pick a location near other "fetch/prefetch"-style recipes (after `github-fetch-hash` is a good fit). Append:

```just
# Prefetch a wallpaper URL and emit a fetchurl entry for packages/wallpapers/default.nix
# Usage: just wallpaper-add <name> <url>
# Example: just wallpaper-add my-mountain "https://images.unsplash.com/photo-...?w=1920"
wallpaper-add name url:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📥 Prefetching {{url}}..."
    hash=$(nix-prefetch-url --name "{{name}}.jpg" --type sha256 "{{url}}" 2>/dev/null | tail -1)
    sri=$(nix hash convert --to sri --hash-algo sha256 "$hash")
    echo ""
    echo "Add this to packages/wallpapers/default.nix:"
    echo ""
    echo "    {{name}} = pkgs.fetchurl {"
    echo "      name = \"{{name}}.jpg\";"
    echo "      url  = \"{{url}}\";"
    echo "      hash = \"$sri\";"
    echo "    };"
```

Notes:
- Hardcoded `.jpg` extension matches the current registry (Unsplash returns JPG). If a future URL serves PNG, the user edits the printed entry. Acceptable trade-off — keeps the recipe simple.
- `name url` order chosen because `name` is the short identifier; `url` is the long blob. Matches the readable order in the printed entry.

- [ ] **Step 2: Append `wallpaper-list` recipe**

```just
# List available wallpapers in the wallpapers package registry
wallpaper-list:
    #!/usr/bin/env bash
    set -euo pipefail
    system=$(nix eval --impure --raw --expr 'builtins.currentSystem')
    echo "🖼️  Available wallpapers:"
    nix eval --json ".#packages.${system}.wallpapers.names" | jq -r '.[]' | sed 's/^/  /'
```

The `currentSystem` detection mirrors the existing `info` recipe at line 125.

- [ ] **Step 3: Format and verify**

```bash
just format
just check
just wallpaper-list
```

Expected for `just wallpaper-list`:

```
🖼️  Available wallpapers:
  green-plains-on-mountain
  sun-light-passing-through-green-leafed-tree
  the-sun-shines-through-the-fog-in-the-mountains
```

- [ ] **Step 4: Smoke-test `wallpaper-add` against an existing URL**

```bash
just wallpaper-add green-plains-on-mountain "https://images.unsplash.com/photo-1547285629-6cab32b3dfdb?ixlib=rb-4.1.0&q=85&fm=jpg&crop=entropy&cs=srgb&dl=med-nadjib-ramdane-yg9fwePu9Og-unsplash.jpg&w=1920"
```

Expected: prints a `fetchurl` block with `hash = "sha256-JHbmgI3HtDAek6MCLs9j6P4ATsgHt4JWJTD6Qhi0jbk="` (i.e., matches the existing registry entry — confirms the recipe produces correct output).

- [ ] **Step 5: Commit**

```bash
git -C /Users/oleksandrsy/.nix-config add justfile
git -C /Users/oleksandrsy/.nix-config commit -m "$(cat <<'EOF'
feat(justfile): add wallpaper-add and wallpaper-list recipes

wallpaper-add <name> <url> prefetches a URL and emits a paste-ready
fetchurl entry for packages/wallpapers/default.nix. wallpaper-list
prints registry names for the current system. Adds do not auto-mutate
the Nix file — output is printed for human review and copy-paste,
matching the explicit-state pattern used by bootstrap-secrets.
EOF
)"
```

---

## Task 4: Final validation

- [ ] **Step 1: Full quality check**

```bash
just check
```

Expected: passes (format-check + statix + deadnix).

- [ ] **Step 2: Full flake evaluation**

```bash
nix flake check --no-build
```

Expected: passes.

- [ ] **Step 3: Verify each host's resolved wallpaper path**

```bash
nix eval '.#nixosConfigurations.desktop.config.stylix.image' --raw
nix eval '.#homeConfigurations."oleksandrsy@workbook".config.stylix.image' --raw
nix eval '.#homeConfigurations."alexander@vm".config.stylix.image' --raw
nix eval '.#homeConfigurations."alexander@desktop".config.stylix.image' --raw
```

Expected: each prints a `/nix/store/...` path ending in `green-plains-on-mountain.jpg`.

- [ ] **Step 4: Confirm only-referenced-is-fetched**

```bash
nix build --no-link --dry-run '.#nixosConfigurations.desktop.config.system.build.toplevel' 2>&1 | grep -c 'wallpapers' || true
```

Inspect the output — only the `green-plains-on-mountain` derivation should appear; the other two wallpapers must NOT be in the build plan.

- [ ] **Step 5: Branch is ready for merge**

```bash
git -C /Users/oleksandrsy/.nix-config log master..HEAD --oneline
```

Expected: 4 commits (1 spec doc from brainstorming + 3 implementation commits).

Once validated, follow the project's PR workflow (per `~/.claude/CLAUDE.md`: PR title in Conventional Commits format, branch based off `master`).

---

## Risks & Rollback

- **Eval failure mid-task:** Each task is one atomic commit. If a task's verification step fails, revert with `git -C /Users/oleksandrsy/.nix-config reset --hard HEAD` (the previous commit) and re-attempt.
- **Unsplash CDN URL rot:** Hashes are pinned, so if Unsplash changes the URL contents, builds will fail with a hash mismatch (loud, not silent). Re-prefetch via `just wallpaper-add` to refresh the entry.
- **macOS Automation permission denied:** Manual one-time grant in System Settings; persists across rebuilds.
- **Sonoma reboot quirk (wallpaper reverts after reboot):** Not addressed in this plan. If observed, follow-up task swaps `osascript` for `pkgs.desktoppr` in `modules/home/desktops/wallpaper/default.nix`.
