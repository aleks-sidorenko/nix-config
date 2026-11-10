{ config, inputs, ... }:
let
  settings = {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      sharedModules = config.plumbing.homeManager;
    };
  };

  hmUser = {
    home-manager.users.hm-test.home.stateVersion = "26.05";
  };
  nixos = config.builders.nixos "x86_64-linux" {
    imports = [ hmUser ];
    system.stateVersion = "26.05";
    users.users.hm-test.isNormalUser = true;
  };
  darwin = config.builders.darwin "aarch64-darwin" {
    imports = [ hmUser ];
    system.stateVersion = 5;
    users.users.hm-test.home = "/Users/hm-test";
  };
in
{
  plumbing.nixos = [
    inputs.home-manager.nixosModules.home-manager
    settings
  ];
  plumbing.darwin = [
    inputs.home-manager.darwinModules.home-manager
    settings
  ];

  evalTests = {
    nixos-hm-global-pkgs = {
      expr = nixos.config.home-manager.useGlobalPkgs;
      expected = true;
    };
    nixos-hm-user = {
      expr = nixos.config.home-manager.users.hm-test.home.username;
      expected = "hm-test";
    };
    darwin-hm-user = {
      expr = darwin.config.home-manager.users.hm-test.home.username;
      expected = "hm-test";
    };
  };
}
