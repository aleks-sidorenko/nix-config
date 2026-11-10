# packages/

One directory per custom package:
- a flake-parts module that adds `perSystem.packages.<name>`
- `_package.nix`, the `callPackage` file, which import-tree skips

From `master`:
- `packages/disk-report`
- `packages/media-tools`
- `packages/phone-tools`
- `packages/wallpapers`

Each moves in the milestone that first uses it. Overlays live in `../nix/nixpkgs.nix`.

Rules: [../README.md](../README.md).
