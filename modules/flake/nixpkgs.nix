{ inputs, ... }:
{
  flake-file.inputs.nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

  den.default.os.nixpkgs.overlays = [
    (final: _prev: {
      unstable = import inputs.nixpkgs-unstable {
        inherit (final.stdenv.hostPlatform) system;
        inherit (final) config;
      };
    })
  ];
}
