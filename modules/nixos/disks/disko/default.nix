{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
with types;
let
  cfg = config.${namespace}.disks.disko;
  
{ lib, ... }:


  partitionType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "Partition name";
      };
      size = mkOption {
        type = types.str;
        description = "Partition size (e.g., '512M' or '100%')";
      };
      type = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Partition type (e.g., 'EF00' for ESP)";
      };
      label = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Partition label";
      };
      content = mkOption {
        type = types.nullOr (types.submodule {
          options = {
            filesystem = mkOption {
              type = types.nullOr (types.submodule {
                options = {
                  format = mkOption {
                    type = types.str;
                    description = "Filesystem format (e.g., 'vfat', 'btrfs')";
                  };
                  mountpoint = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Mount point for this filesystem";
                  };
                  mountOptions = mkOption {
                    type = types.listOf types.str;
                    default = [];
                    description = "Mount options for this filesystem";
                  };
                  subvolumes = mkOption {
                    type = types.attrsOf subvolumeType;
                    default = {};
                    description = "Btrfs subvolumes (if using btrfs)";
                  };
                };
              });
              default = null;
            };
            luks = mkOption {
              type = types.nullOr (types.submodule {
                options = {
                  name = mkOption {
                    type = types.str;
                    description = "LUKS device name";
                  };
                  fido2 = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Enable FIDO2 authentication";
                  };
                  allowDiscards = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Allow TRIM/discard commands";
                  };
                };
              });
              default = null;
            };
          };
        });
        default = null;
        description = "Partition content configuration";
      };
    };
  };

in
{
  options = {
    snowfall.disks = {
      enable = lib.mkEnableOption "Whether to enable the snowfall disk configuration";

      disks = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            device = mkOption {
              type = types.str;
              description = "The device path for the disk (e.g., '/dev/sda')";
            };
            partitions = mkOption {
              type = types.listOf partitionType;
              default = [];
              description = "Partitions to create on this disk";
            };
          };
        });
        default = {};
        description = "Disks to configure, keyed by disk name";
      };
    };
  };

  config = let
    cfg = config.snowfall.disks;

    mkContent = content:
      if content == null then null
      else if content.luks != null then {
        type = "luks";
        name = content.luks.name;
        settings = {
          allowDiscards = content.luks.allowDiscards;
          crypttabExtraOpts = lib.optionals content.luks.fido2 [
            "fido2-device=auto"
            "token-timeout=10"
          ];
        };
        content = mkContent content.filesystem;
      }
      else if content.filesystem != null then {
        type = "filesystem";
        inherit (content.filesystem) format;
        mountpoint = content.filesystem.mountpoint;
        mountOptions = content.filesystem.mountOptions;
        content = if content.filesystem.subvolumes != {} then {
          type = "btrfs";
          extraArgs = ["-f" "-L ${content.filesystem.format}"]; # Hardcoded extraArgs
          subvolumes = lib.mapAttrs (name: sv: {
            inherit (sv) mountpoint;
            mountOptions = content.filesystem.mountOptions ++ sv.mountOptions;
          } // (lib.optionalAttrs (sv.swapfile != null) {
            swap.swapfile.size = sv.swapfile.size;
          })) content.filesystem.subvolumes;
        } else null;
      }
      else null;

  in lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.disks != {};
        message = "At least one disk must be specified in snowfall.disks.disks";
      }
    ];

    disko.devices = {
      disk = lib.mapAttrs (name: disk: {
        inherit (disk) device;
        type = "disk";
        name = name;
        content = {
          type = "gpt";
          partitions = lib.listToAttrs (map (part: {
            name = part.name;
            value = {
              inherit (part) size type label;
              content = mkContent part.content;
            };
          }) disk.partitions);
        };
      }) cfg.disks;
    };

    fileSystems = lib.mkMerge (
      lib.flatten (lib.mapAttrsToList (_: disk:
        lib.concatMap (part:
          lib.optional (part.content != null && part.content.filesystem != null && part.content.filesystem.mountpoint != null)
            (lib.optionalAttrs (lib.hasPrefix "/persist" part.content.filesystem.mountpoint ||
                               lib.hasPrefix "/var/log" part.content.filesystem.mountpoint) {
              ${part.content.filesystem.mountpoint}.neededForBoot = true;
            })
        ) disk.partitions
      ) cfg.disks
    );
  };
}