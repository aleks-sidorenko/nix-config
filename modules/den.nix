{
  den,
  inputs,
  lib,
  ...
}:
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

  den = {
    migrations.user-host-content.acknowledged = true;

    reservedKeys = [ "settings" ];

    schema.host = {
      includes = [
        den.batteries.hostname
        den.batteries.mutual-provider
        den.aspects.system.nix
        den.aspects.system.nixpkgs
        den.aspects.system.locale
        den.aspects.system.networking
        den.aspects.security.ssh
      ];

      options = {
        stateVersion = lib.mkOption {
          type = lib.types.str;
          description = "Release the host's and its users' stateful data was first created with.";
        };
        settings = lib.mkOption {
          type = import ./_lib/settings-type.nix { inherit den lib; };
          default = { };
          description = "Per-host values for the settings aspects declare, at the aspect's path.";
        };
      };

      imports = [
        (
          { config, ... }:
          {
            options.primaryUser = lib.mkOption {
              type = lib.types.str;
              default =
                let
                  users = lib.attrValues config.users;
                in
                if lib.length users == 1 then
                  (lib.head users).userName
                else
                  throw "host ${config.name}: set primaryUser, it has ${toString (lib.length users)} users";
              defaultText = "the host's only user";
              description = "Account that administers the host: deploy-rs logs in as it, and web UIs with their own login use its name.";
            };
          }
        )
      ];
    };

    schema.user = {
      includes = [
        den.batteries.define-user
        den.aspects.security.user-password
      ];
      classes = lib.mkDefault [ "homeManager" ];
    };

    default = {
      nixos =
        { host, ... }:
        {
          system.stateVersion = host.stateVersion;
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
          };
        };
      homeManager =
        { host, ... }:
        {
          home.stateVersion = host.stateVersion;
        };
    };
  };
}
