{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
  hostNameModule = name: { networking.hostName = lib.mkDefault name; };
  testDefaults = stateVersion: {
    system.stateVersion = lib.mkDefault stateVersion;
    home-manager.sharedModules = [ { home.stateVersion = lib.mkDefault "26.05"; } ];
  };
  nixos = config.builders.testNixos { };
  darwin = config.builders.testDarwin { };
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
    testNixos = mkOption {
      type = types.raw;
      readOnly = true;
      description = "`module -> nixosSystem` for eval tests: x86_64-linux, with stateVersions defaulted.";
    };
    testDarwin = mkOption {
      type = types.raw;
      readOnly = true;
      description = "`module -> darwinSystem` for eval tests: aarch64-darwin, with stateVersions defaulted.";
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
      testNixos =
        module:
        config.builders.nixos "x86_64-linux" {
          imports = [
            module
            (testDefaults "26.05")
          ];
        };
      testDarwin =
        module:
        config.builders.darwin "aarch64-darwin" {
          imports = [
            module
            (testDefaults 5)
          ];
        };
    };

    flake.lib = {
      mkNixos =
        system: name:
        config.builders.nixos system {
          imports = [
            config.flake.modules.nixos.${name}
            (hostNameModule name)
          ];
        };
      mkDarwin =
        system: name:
        config.builders.darwin system {
          imports = [
            config.flake.modules.darwin.${name}
            (hostNameModule name)
          ];
        };
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
      builder-hostname = {
        expr = (config.builders.testNixos (hostNameModule "probe")).config.networking.hostName;
        expected = "probe";
      };
      test-nixos-defaults = {
        expr = with (config.builders.testNixos { }).config; [
          system.stateVersion
          nixpkgs.hostPlatform.system
        ];
        expected = [
          "26.05"
          "x86_64-linux"
        ];
      };
      test-nixos-hm-state-version = {
        expr =
          (config.builders.testNixos {
            users.users.probe.isNormalUser = true;
            home-manager.users.probe = { };
          }).config.home-manager.users.probe.home.stateVersion;
        expected = "26.05";
      };
      test-darwin-defaults = {
        expr = (config.builders.testDarwin { }).config.system.stateVersion;
        expected = 5;
      };
      darwin-platform = {
        expr = darwin.pkgs.stdenv.hostPlatform.system;
        expected = "aarch64-darwin";
      };
    };
  };
}
