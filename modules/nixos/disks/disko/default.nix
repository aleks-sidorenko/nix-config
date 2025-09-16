{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with types;
let
  cfg = config.${namespace}.disks.disko;

  subvolume = name: "@${name}";
  blank = name: "${name}-blank";
  encryped = name: "${name}_encrypted";
  mountpoint = subvol: if subvol.mountpoint != null then subvol.mountpoint else "/${subvol.name}";

  mkBootPartition =
    disk:
    (optionalAttrs (disk.boot != null) {
      boot = {
        priority = 1;
        label = disk.boot.name;
        size = disk.boot.size;
        type = "EF00";
        content = {
          type = "filesystem";
          extraArgs = [ "-n${disk.boot.name}" ];
          format = "vfat";
          mountpoint = "/boot";
          mountOptions = [ "umask=0077" ];
        };
      };
    });

  mkSubvolumes =
    disk:
    let

      mkSubvolume = subvol: {
        ${subvolume subvol.name} =
          {
            mountpoint = mountpoint subvol;
            inherit (subvol) mountOptions;
          }
          // optionalAttrs (subvol.swapfile != null) {
            swap.swapfile.size = subvol.swapfile.size;
          };
      };
    in
    foldl' (acc: subvol: acc // mkSubvolume subvol) { } disk.content;

  mkBtrfsContent = disk: {
    type = "btrfs";
    extraArgs = [
      "-f" # force overwrite
      "-L ${disk.name}" # label we use later on in postCreateHook
    ];
    # Create snapshot regardless of if impermanence is enabled
    # This way we can enable impermanence later on if we want
    postCreateHook =
      let
        subvols = lib.filter (sv: sv.createBlankSnapshot) disk.content;
        snapshotCommands = map (
          subvol:
          let
            name = subvol.name;
          in
          ''
            echo "Creating blank snapshot of ${subvolume name}"
            btrfs subvolume snapshot -r "$MNTPOINT/${subvolume name}" "$MNTPOINT/${subvolume (blank name)}"
          ''
        ) subvols;
      in
      optionalString (builtins.length subvols > 0) ''
        mkdir -p /tmp
        MNTPOINT=$(mktemp -d)
        mount -t btrfs /dev/disk/by-label/${disk.name} "$MNTPOINT"
        trap 'umount "$MNTPOINT"; rm -rf "$MNTPOINT"' EXIT
        ${concatStringsSep "\n" snapshotCommands}
      '';
    subvolumes = mkSubvolumes disk;
  };

  mkLuksPartition = disk: {
    encryped = {
      size = "100%";
      label = encryped disk.name;
      content = {
        type = "luks";
        inherit (disk) name;
        # passwordFile used during nixos-anywhere installation only
        # For runtime boot decryption, system will use FIDO2 device or prompt for password
        passwordFile = "/tmp/disk.key";
        settings = {
          allowDiscards = true;
          crypttabExtraOpts = [
            "fido2-device=auto"
            "token-timeout=10"
          ];
        };
        # Subvolumes must set a mountpoint in order to be mounted,
        # unless their parent is mounted
        content = mkBtrfsContent disk;
      };
    };
  };

  mkBtrfsPartition = disk: {
    btrfs = {
      size = "100%";
      label = disk.name;
      content = mkBtrfsContent disk;
    };
  };

  mkDisk = disk: {
    inherit (disk) device;
    type = "disk";
    name = disk.name;
    content = {
      type = "gpt";
      partitions =
        mkBootPartition disk // (if disk.encrypted then mkLuksPartition disk else mkBtrfsPartition disk);
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
          encrypted = mkOption {
            type = types.bool;
            default = false;
            description = "Whether to use LUKS encryption for the partition";
          };

          boot = mkOption {
            type = types.nullOr (submodule {
              options = {
                name = mkOption {
                  type = types.str;
                  default = lib.${namespace}.defaults.disks.boot;
                  description = "Name of the boot partition";
                };
                size = mkOption {
                  type = types.str;
                  default = "512M";
                  description = "Size of the boot partition (e.g., '512M')";
                };
              };
            });
            default = null;
            description = "Boot partition configuration";
          };

          content = mkOption {
            type = types.listOf (submodule {
              options = {
                name = mkOption {
                  type = str;
                  description = "Name of the subvolume (without @ prefix)";
                };
                mountpoint = mkOption {
                  type = nullOr str;
                  default = null;
                  description = "Mount point for the subvolume";
                };
                mountOptions = mkOption {
                  type = listOf types.str;
                  default = [
                    "compress=zstd"
                    "noatime"
                  ];
                  description = "Mount options for the subvolume";
                };
                swapfile = mkOption {
                  type = nullOr (submodule {
                    options = {
                      size = mkOption {
                        type = str;
                        description = "Size of the swapfile (e.g., '8G')";
                      };
                    };
                  });
                  default = null;
                  description = "Swapfile configuration for this subvolume";
                };
                createBlankSnapshot = mkOption {
                  type = bool;
                  default = false;
                  description = "Whether to create a blank snapshot of this subvolume";
                };
                neededForBoot = mkOption {
                  type = bool;
                  default = false;
                  description = "Whether this subvolume is needed during early boot";
                };
              };
            });
            default = [ ];
            description = "List of btrfs subvolumes to create";
          };

        };
      });
      default = { };
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
      disk = lib.mapAttrs (name: disk: mkDisk (disk // { inherit name; })) cfg.disks;
    };

    # Set neededForBoot for all content's subvolumes that require it
    fileSystems =
      let
        allSubvolumes = lib.flatten (map (disk: disk.content) (builtins.attrValues cfg.disks));
        bootSubvolumes = builtins.filter (subvol: subvol.neededForBoot) allSubvolumes;
      in
      lib.listToAttrs (
        map (subvol: {
          name = mountpoint subvol;
          value.neededForBoot = true;
        }) bootSubvolumes
      );
  };
}
