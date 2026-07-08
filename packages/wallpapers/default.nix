{
  inputs,
  pkgs,
  ...
}:
# Wallpapers live in the standalone, reusable `nix-wallpapers` flake. The images are
# vendored there (committed, not fetched at build time), so the bytes never drift and
# builds stay hermetic. This just re-exports the package for the host platform, keeping
# the `pkgs.${namespace}.wallpapers` API (`.names` + per-name passthru) unchanged.
inputs.nix-wallpapers.packages.${pkgs.stdenv.hostPlatform.system}.default
