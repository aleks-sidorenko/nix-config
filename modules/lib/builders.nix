{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
  nixos = config.builders.nixos "x86_64-linux" { system.stateVersion = "26.05"; };
  darwin = config.builders.darwin "aarch64-darwin" { system.stateVersion = 5; };
in
{
  options.builders = {
    nixos = mkOption {
      type = types.raw;
      readOnly = true;
      description = "`system -> module -> nixosSystem`, with the nixos plumbing included.";
    };
    darwin = mkOption {
      type = types.raw;
      readOnly = true;
      description = "`system -> module -> darwinSystem`, with the darwin plumbing included.";
    };
  };

  config = {
    builders = {
      nixos =
        system: module:
        inputs.nixpkgs.lib.nixosSystem {
          modules = config.plumbing.nixos ++ [
            module
            { nixpkgs.hostPlatform = system; }
          ];
        };
      darwin =
        system: module:
        inputs.darwin.lib.darwinSystem {
          modules = config.plumbing.darwin ++ [
            module
            { nixpkgs.hostPlatform = system; }
          ];
        };
    };

    flake.lib = {
      mkNixos = system: name: config.builders.nixos system config.flake.modules.nixos.${name};
      mkDarwin = system: name: config.builders.darwin system config.flake.modules.darwin.${name};
    };

    evalTests = {
      nixos-unfree = {
        expr = nixos.config.nixpkgs.config.allowUnfree;
        expected = true;
      };
      nixos-unstable = {
        expr = nixos.pkgs ? unstable;
        expected = true;
      };
      nixos-platform = {
        expr = nixos.pkgs.stdenv.hostPlatform.system;
        expected = "x86_64-linux";
      };
      darwin-unfree = {
        expr = darwin.config.nixpkgs.config.allowUnfree;
        expected = true;
      };
      darwin-platform = {
        expr = darwin.pkgs.stdenv.hostPlatform.system;
        expected = "aarch64-darwin";
      };
    };
  };
}
