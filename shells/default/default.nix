{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;
in
pkgs.mkShell {
  NIX_CONFIG = "extra-experimental-features = nix-command flakes";

  shellHook = ''
    export FLAKE_DIR="$HOME/.nix-config"
  '';

  packages =
    with pkgs;
    [
      nix
      nh
      deploy-rs
      statix
      deadnix
      alejandra
      home-manager
      git
      sops
      ssh-to-age
      gnupg
      age
      mkpasswd
      just
    ]
    # Not packaged for every system the flake generates shells for.
    ++ lib.optional (
      inputs.nixos-anywhere.packages ? ${system}
    ) inputs.nixos-anywhere.packages.${system}.nixos-anywhere;
}
