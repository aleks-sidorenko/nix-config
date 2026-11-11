{ config, ... }:
let
  c = (config.builders.testNixos config.flake.modules.nixos.nix-ld).config;
in
{
  flake.modules.nixos.nix-ld = {
    programs.nix-ld.enable = true;
  };

  evalTests = {
    nix-ld-enabled = {
      expr = c.programs.nix-ld.enable;
      expected = true;
    };
  };
}
