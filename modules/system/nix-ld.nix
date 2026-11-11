{ config, ... }:
let
  c =
    (config.builders.nixos "x86_64-linux" {
      imports = [ config.flake.modules.nixos.nix-ld ];
      system.stateVersion = "26.05";
    }).config;
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
