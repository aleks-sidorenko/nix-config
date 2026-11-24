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
    # Published for entity kinds declared elsewhere that belong to a person too.
    identityType = lib.mkOption {
      type = lib.types.optionType;
      readOnly = true;
      description = "Type of an entity's `identity`: a folder under identities/, loaded into its keys and git data.";
    };
    hostsWith = lib.mkOption {
      type = lib.types.functionTo lib.types.raw;
      readOnly = true;
      description = "The hosts of every system whose include tree holds the given aspect, by name.";
    };
  };

  config = {
    isReservedKey = import ./_reserved-key.nix { inherit den; };
    settingsType = import ./_settings-type.nix { inherit den lib; };
    # The only place that knows where identities live. Files are read on
    # first use, so a user without a key never needs that file.
    identityType = lib.types.coercedTo lib.types.str (
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
    hostsWith =
      aspect:
      lib.filterAttrs (_: host: host.hasAspect aspect) (lib.mergeAttrsList (lib.attrValues den.hosts));

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
          den.aspects.system.lan
          den.aspects.security.ssh
        ];

        options = {
          stateVersion = lib.mkOption {
            type = lib.types.str;
            description = "Release the host's and its users' stateful data was first created with.";
          };
          lan = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.submodule {
                options = {
                  address = lib.mkOption {
                    type = lib.types.str;
                    description = "IPv4 address the router leases to the host.";
                  };
                  mac = lib.mkOption {
                    type = lib.types.str;
                    description = "MAC address of the interface the host reaches the LAN on.";
                  };
                };
              }
            );
            default = null;
            description = "The host's fixed address and MAC on the home LAN; the router gives it a static lease.";
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
          (user: {
            options.identity = lib.mkOption {
              type = config.identityType;
              default = user.config.name;
              defaultText = "the user's name";
              description = "The person behind the account.";
            };
          })
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
