{ inputs, lib, ... }:
{
  imports = [
    inputs.den.flakeModules.dendritic
    inputs.flake-file.flakeModules.dendritic
    inputs.flake-file.flakeModules.auto-follow
  ];

  systems = [
    "x86_64-linux"
    "aarch64-darwin"
  ];

  flake-file.inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    import-tree.url = "github:denful/import-tree";
    den.url = "github:denful/den";
    flake-file.url = "github:denful/flake-file";
  };

  den.schema.user.classes = lib.mkDefault [ "homeManager" ];
}
