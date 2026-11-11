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
    let
      sshKey = (config.flake.lib.identity name).sshPublicKey;
    in
    {
      nixos =
        { config, ... }:
        {
          imports = [ (home name) ];

          # Passwords come only from SOPS: with mutableUsers off, anything
          # else would be a plaintext password in the store.
          sops.secrets."user-${name}-password".neededForUsers = true;

          users.users.${name} = {
            isNormalUser = true;
            group = "users";
            extraGroups = [
              "networkmanager"
              "input"
              "tty"
            ]
            ++ lib.optional admin "wheel";
            hashedPasswordFile = config.sops.secrets."user-${name}-password".path;
            openssh.authorizedKeys.keys = lib.optional (sshKey != null) sshKey;
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

  adminHost = config.builders.testNixos {
    imports = [
      admin.nixos
      config.flake.modules.nixos.sops
    ];
  };
  plainHost = config.builders.testNixos {
    imports = [
      plain.nixos
      config.flake.modules.nixos.sops
    ];
  };
  darwinHost = config.builders.testDarwin {
    imports = [ admin.darwin ];
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
      factory-groups = {
        expr = adminHost.config.users.users.factory-test.extraGroups;
        expected = [
          "networkmanager"
          "input"
          "tty"
          "wheel"
        ];
      };
      factory-password-secret = {
        expr = adminHost.config.users.users.factory-test.hashedPasswordFile;
        expected = "/run/secrets-for-users/user-factory-test-password";
      };
      factory-secret-for-users = {
        expr = adminHost.config.sops.secrets."user-factory-test-password".neededForUsers;
        expected = true;
      };
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
