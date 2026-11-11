{ config, inputs, ... }:
let
  settings = {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      sharedModules = config.plumbing.homeManager;
      # Move unmanaged files aside instead of aborting activation when
      # home-manager wants to own a path something else already created.
      backupFileExtension = "backup";
    };
  };

  hmUser = {
    home-manager.users.hm-test = { };
  };
  nixos = config.builders.testNixos {
    imports = [ hmUser ];
    users.users.hm-test.isNormalUser = true;
  };
  darwin = config.builders.testDarwin {
    imports = [ hmUser ];
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
    nixos-hm-backup-ext = {
      expr = nixos.config.home-manager.backupFileExtension;
      expected = "backup";
    };
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
