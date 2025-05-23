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

  subvolume = name: "@${name}";
  blank = name: "${name}-blank";
  encryped = name: "${name}_encrypted";

  mkBootPartition =
    let
      boot = {
        ESP = {
          priority = 1;
          name = "ESP";
          label = "boot";
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            extraArgs = [ "-nESP" ];
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "defaults" ];
          };
        };
      };
    in
    boot;

  mkSubvolumes = disk:
    let
      defaultMountOptions = [
        "compress=zstd"
        "noatime"
      ];
      
      mkSubvolume = subvol: {
        ${subvolume subvol.name} = {
          mountpoint = if subvol.mountpoint != null 
            then subvol.mountpoint
            else "/${subvol.name}";
          mountOptions = if (lists.length subvol.mountOptions) > 0 
            then subvol.mountOptions 
            else defaultMountOptions;
        } // optionalAttrs (subvol.swapfile != null) {
          swap.swapfile.size = subvol.swapfile.size;
        };
      };
    in
    foldl' (acc: subvol: acc // mkSubvolume subvol) {} disk.subvolumes;

  mkLuksPartition = disk: {
    encryped = {
      size = "100%";
      label = encryped disk.name;
      content = {
        type = "luks";
        inherit (disk) name;
        settings = {
          allowDiscards = true;
          crypttabExtraOpts = [
            "fido2-device=auto"
            "token-timeout=10"
          ];
        };
        # Subvolumes must set a mountpoint in order to be mounted,
        # unless their parent is mounted
        content = {
          type = "btrfs";
          extraArgs = [
            "-f" # force overwrite
            "-L ${disk.name}" # label we use later on in postCreateHook
          ];
          # Create snapshot regardless of if impermanence is enabled
          # This way we can enable impermanence later on if we want
          postCreateHook =
            let
              subvols = lib.filterAttrs (sv: sv.createBlankSnapshot) disk.subvolumes;
              snapshotCommands = lib.mapAttrsToList (name: _: ''                  
                echo "Creating blank snapshot of ${subvolume name}"
                btrfs subvolume snapshot -r "$MNTPOINT/${subvolume name}" "$MNTPOINT/${subvolume (blank name)}"
              '') subvols;
            in
            optionalString (!lists.isEmpty subvols) ''
              mkdir -p /tmp
              MNTPOINT=$(mktemp -d)
              mount -t btrfs /dev/disk/by-label/${disk.name} "$MNTPOINT"
              trap 'umount "$MNTPOINT"; rm -rf "$MNTPOINT"' EXIT
              ${concatStringsSep "\n" snapshotCommands}
            '';
          subvolumes = mkSubvolumes disk;
        };
      };
    };
  };

  mkDisk = disk: {
    inherit (disk) device;
    type = "disk";
    name = disk.name;
    content = {
      type = "gpt";
      partitions = optionalAttrs disk.boot (mkBootPartition disk) // mkLuksPartition disk;
    };
  };

in
{
  options.${namespace}.disks.disko = {
    enable = mkEnableOption "Whether to enable the disko disk configuration";

    disks = mkOption {
      type = attrsOf (submodule {
        options = {
          device = mkOption {
            type = types.str;
            description = "The device path for the disk (e.g., '/dev/sda')";
          };
          name = mkOption {
            type = types.str;
            description = "The name of the disk";
          };
          boot = mkBoolOpt false "Whether this disk is a boot disk";
          subvolumes = mkOption {
            type = types.listOf (submodule {
              options = {
                name = mkOption {
                  type = types.str;
                  description = "Name of the subvolume (without @ prefix)";
                };
                mountpoint = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Mount point for the subvolume";
                };
                mountOptions = mkOption {
                  type = types.listOf types.str;
                  default = [];
                  description = "Mount options for the subvolume";
                };
                swapfile = mkOption {
                  type = types.nullOr (submodule {
                    options = {
                      size = mkOption {
                        type = types.str;
                        description = "Size of the swapfile (e.g., '8G')";
                      };
                    };
                  });
                  default = null;
                  description = "Swapfile configuration for this subvolume";
                };
                createBlankSnapshot = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Whether to create a blank snapshot of this subvolume";
                };
              };
            });
            default = [];
            description = "List of btrfs subvolumes to create";
          };
        };
      });
      default = {};
      description = "Disks to configure";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.disks != { };
        message = "At least one disk must be specified";
      }
    ];

    disko.devices = {
      disk = lib.mapAttrs (name: disk: mkDisk disk) cfg.disks;
    };

  };
}
