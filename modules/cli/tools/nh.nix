{ config, ... }:
let
  c = (config.builders.testNixos config.flake.modules.nixos.nh).config;
in
{
  flake.modules.nixos.nh =
    { lib, ... }:
    {
      programs.nh = {
        enable = true;
        clean = {
          enable = true;
          extraArgs = "--keep-since 7d --keep 5";
        };
        flake = "/home/${config.constants.owner}/.nix-config";
      };
      # nh's clean and nix.gc both collect garbage; NixOS warns when both run.
      nix.gc.automatic = lib.mkForce false;
    };

  evalTests = {
    nh-clean = {
      expr = c.programs.nh.clean.extraArgs;
      expected = "--keep-since 7d --keep 5";
    };
    nh-flake = {
      expr = c.programs.nh.flake;
      expected = "/home/alexander/.nix-config";
    };
  };
}
