# One package per host, wrapping nh: `nix run .#<host> -- switch`.
{
  config,
  den,
  lib,
  ...
}:
let
  images = lib.attrNames (
    lib.filterAttrs (_: system: system.config ? isoImage) config.flake.nixosConfigurations
  );
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages = removeAttrs (den.lib.nh.denPackages { fromFlake = true; } pkgs) images;
    };

  # Switching a running machine to an installer image would replace its system.
  evalTests.nh-skips-images = {
    expr = {
      images = images != [ ];
      wrapped = lib.filter (name: config.allSystems.aarch64-darwin.packages ? ${name}) images;
    };
    expected = {
      images = true;
      wrapped = [ ];
    };
  };
}
