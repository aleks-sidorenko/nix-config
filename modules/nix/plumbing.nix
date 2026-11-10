{ lib, ... }:
let
  inherit (lib) mkOption types;
  plumbing =
    class:
    mkOption {
      type = types.listOf types.deferredModule;
      default = [ ];
      description = "Modules every ${class} configuration gets from the host builders. Plumbing only, never features.";
    };
in
{
  options.plumbing = {
    nixos = plumbing "nixos";
    darwin = plumbing "darwin";
    homeManager = plumbing "home-manager";
  };
}
