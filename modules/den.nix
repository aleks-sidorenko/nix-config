{
  config,
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

  options = {
    # Published for the naming check; `_settings-type.nix` beside this file imports it directly.
    isReservedKey = lib.mkOption {
      type = lib.types.functionTo lib.types.bool;
      readOnly = true;
      description = "Whether den reads a key inside an aspect as pipeline machinery, class content or quirk data, never as a child aspect.";
    };
    # Published for entity kinds declared elsewhere that take settings too.
    settingsType = lib.mkOption {
      type = lib.types.optionType;
      readOnly = true;
      description = "Type of an entity's `settings`: the settings every aspect declares, at the aspect's path.";
    };
  };

  config = {
    isReservedKey = import ./_reserved-key.nix { inherit den; };
    settingsType = import ./_settings-type.nix { inherit den lib; };

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
            type = config.settingsType;
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

        imports = [
          (
            { config, ... }:
            {
              # The only place that knows where identities live. Files are read
              # on first use, so a user without a key never needs that file.
              options.identity = lib.mkOption {
                type = lib.types.coercedTo lib.types.str (
                  name:
                  let
                    dir = ../identities + "/${name}";
                    read = file: lib.trim (builtins.readFile (dir + "/${file}"));
                  in
                  {
                    inherit name;
                    sshKeyFile = dir + "/ssh.pub";
                    sshKey = read "ssh.pub";
                    gpgKeyFile = dir + "/gpg.pub.asc";
                    gpgKeyId = read "gpg.key-id";
                    git = builtins.fromJSON (read "git.json");
                  }
                ) lib.types.raw;
                default = config.name;
                defaultText = "the user's name";
                description = "The person behind the account: a folder under identities/, loaded into its keys and git data.";
              };
            }
          )
        ];
      };

      default = {
        nixos =
          { host, ... }:
          {
            system.stateVersion = host.stateVersion;
          };
        os = {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            # A file home-manager now manages but the user already has (a
            # shell's default config) is moved aside instead of failing activation.
            backupFileExtension = "backup";
          };
        };
        homeManager =
          { host, ... }:
          {
            home.stateVersion = host.stateVersion;
          };
      };
    };
  };
}
