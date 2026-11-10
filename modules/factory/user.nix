{ config, lib, ... }:
let
  # A user may have no home-manager aspect of their own yet.
  home = name: {
    home-manager.users.${name}.imports = [ (config.flake.modules.homeManager.${name} or { }) ];
  };

  user =
    {
      name,
      admin ? false,
    }:
    {
      nixos = {
        imports = [ (home name) ];
        users.users.${name} = {
          isNormalUser = true;
          extraGroups = lib.optional admin "wheel";
        };
      };
      darwin = {
        imports = [ (home name) ];
        users.users.${name}.home = "/Users/${name}";
      };
    };

  admin = config.factory.user {
    name = "factory-test";
    admin = true;
  };
  plain = config.factory.user { name = "factory-plain"; };

  adminHost = config.builders.nixos "x86_64-linux" {
    imports = [ admin.nixos ];
    system.stateVersion = "26.05";
    home-manager.users.factory-test.home.stateVersion = "26.05";
  };
  plainHost = config.builders.nixos "x86_64-linux" {
    imports = [ plain.nixos ];
    system.stateVersion = "26.05";
    home-manager.users.factory-plain.home.stateVersion = "26.05";
  };
  darwinHost = config.builders.darwin "aarch64-darwin" {
    imports = [ admin.darwin ];
    system.stateVersion = 5;
    home-manager.users.factory-test.home.stateVersion = "26.05";
  };
in
{
  options.factory = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
    description = "Functions that build per-class modules for a feature, such as `user`.";
  };

  config = {
    factory = { inherit user; };

    evalTests = {
      factory-admin-wheel = {
        expr = builtins.elem "wheel" adminHost.config.users.users.factory-test.extraGroups;
        expected = true;
      };
      factory-plain-no-wheel = {
        expr = builtins.elem "wheel" plainHost.config.users.users.factory-plain.extraGroups;
        expected = false;
      };
      factory-home-wired = {
        expr = adminHost.config.home-manager.users.factory-test.home.username;
        expected = "factory-test";
      };
      factory-darwin-home = {
        expr = darwinHost.config.users.users.factory-test.home;
        expected = "/Users/factory-test";
      };
      factory-home-constants = {
        expr = adminHost.config.home-manager.users.factory-test.constants.locale.timeZone;
        expected = "Europe/Kyiv";
      };
    };
  };
}
