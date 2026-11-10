{ inputs, ... }:
let
  config = {
    allowUnfree = true;
  };
  overlays = [
    (final: _: {
      unstable = import inputs.nixpkgs-unstable {
        inherit (final.stdenv.hostPlatform) system;
        inherit config;
      };
    })
  ];
  module = {
    nixpkgs = { inherit config overlays; };
  };
in
{
  plumbing.nixos = [ module ];
  plumbing.darwin = [ module ];

  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs { inherit system config overlays; };
    };
}
