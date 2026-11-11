{
  config,
  inputs,
  lib,
  ...
}:
let
  host =
    disks:
    (config.builders.testNixos {
      imports = [ config.flake.modules.nixos.disko ];
      nix-config.disks = disks;
    }).config;

  plain = host {
    root = {
      device = "/dev/sda";
      boot.size = "1G";
      content = [
        {
          name = "root";
          mountpoint = "/";
          createBlankSnapshot = true;
        }
        {
          name = "persist";
          neededForBoot = true;
        }
        {
          name = "swap";
          swapfile.size = "8G";
        }
      ];
    };
  };
  plainDisk = plain.disko.devices.disk.root;
  plainBtrfs = plainDisk.content.partitions.btrfs.content;

  encrypted = host {
    data = {
      device = "/dev/sdb";
      encrypted = true;
      content = [ { name = "home"; } ];
    };
  };
  encryptedParts = encrypted.disko.devices.disk.data.content.partitions;
in
{
  flake.modules.nixos.disko =
    { config, lib, ... }:
    let
      inherit (lib) mkOption types;
      cfg = config.nix-config.disks;

      subvolume = name: "@${name}";
      mountpointOf = sv: if sv.mountpoint != null then sv.mountpoint else "/${sv.name}";

      bootPartition = disk: {
        boot = {
          priority = 1;
          label = disk.boot.name;
          inherit (disk.boot) size;
          type = "EF00";
          content = {
            type = "filesystem";
            extraArgs = [ "-n${disk.boot.name}" ];
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
      };

      btrfsContent =
        disk:
        let
          snapshotted = builtins.filter (sv: sv.createBlankSnapshot) disk.content;
          snapshot =
            { name, ... }:
            let
              from = "$MNTPOINT/${subvolume name}";
              to = "$MNTPOINT/${subvolume "${name}-blank"}";
            in
            ''
              echo "Creating blank snapshot of ${subvolume name}"
              [ -e "${to}" ] || btrfs subvolume snapshot -r "${from}" "${to}"
            '';
        in
        {
          type = "btrfs";
          # The label is what the blank-snapshot hook and the impermanence
          # rollback mount by.
          extraArgs = [
            "-f"
            "-L ${disk.name}"
          ];
          # Snapshots are taken whether or not impermanence is on, so it can be
          # turned on later without reformatting.
          postCreateHook = lib.optionalString (snapshotted != [ ]) ''
            mkdir -p /tmp
            MNTPOINT=$(mktemp -d)
            mount -t btrfs /dev/disk/by-label/${disk.name} "$MNTPOINT"
            trap 'umount "$MNTPOINT"; rm -rf "$MNTPOINT"' EXIT
            ${lib.concatMapStringsSep "\n" snapshot snapshotted}
          '';
          subvolumes = lib.listToAttrs (
            map (
              sv:
              lib.nameValuePair (subvolume sv.name) (
                {
                  mountpoint = mountpointOf sv;
                  inherit (sv) mountOptions;
                }
                // lib.optionalAttrs (sv.swapfile != null) { swap.swapfile.size = sv.swapfile.size; }
              )
            ) disk.content
          );
        };

      dataPartition =
        disk:
        if disk.encrypted then
          {
            encrypted = {
              size = "100%";
              label = "${disk.name}_encrypted";
              content = {
                type = "luks";
                inherit (disk) name;
                # Read by the installer only; at boot the disk unlocks with a
                # FIDO2 token or a typed password.
                passwordFile = "/tmp/disk.key";
                settings = {
                  allowDiscards = true;
                  crypttabExtraOpts = [
                    "fido2-device=auto"
                    "token-timeout=10"
                  ];
                };
                content = btrfsContent disk;
              };
            };
          }
        else
          {
            btrfs = {
              size = "100%";
              label = disk.name;
              content = btrfsContent disk;
            };
          };

      mkDisk =
        disk:
        {
          inherit (disk) device name;
          type = "disk";
          content = {
            type = "gpt";
            partitions = lib.optionalAttrs (disk.boot != null) (bootPartition disk) // dataPartition disk;
          };
        }
        // lib.optionalAttrs (disk.imageSize != null) { inherit (disk) imageSize; };

      subvolumeType = types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Subvolume name, without the `@` prefix.";
          };
          mountpoint = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Where it mounts; `/<name>` when null.";
          };
          mountOptions = mkOption {
            type = types.listOf types.str;
            default = [
              "compress=zstd"
              "noatime"
            ];
            description = "Mount options.";
          };
          swapfile = mkOption {
            type = types.nullOr (types.submodule { options.size = mkOption { type = types.str; }; });
            default = null;
            description = "A swapfile inside this subvolume.";
          };
          createBlankSnapshot = mkOption {
            type = types.bool;
            default = false;
            description = "Take a read-only `@<name>-blank` snapshot right after creation.";
          };
          neededForBoot = mkOption {
            type = types.bool;
            default = false;
            description = "Mount it in the initrd.";
          };
        };
      };
    in
    {
      imports = [ inputs.disko.nixosModules.disko ];

      options.nix-config.disks = mkOption {
        type = types.attrsOf (
          types.submodule {
            options = {
              device = mkOption {
                type = types.str;
                description = "Device path, e.g. `/dev/disk/by-id/...`.";
              };
              encrypted = mkOption {
                type = types.bool;
                default = false;
                description = "Put the btrfs filesystem inside LUKS.";
              };
              imageSize = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Size of a built disk image; disko's default when null.";
              };
              boot = mkOption {
                type = types.nullOr (
                  types.submodule {
                    options = {
                      name = mkOption {
                        type = types.str;
                        default = "boot";
                        description = "Partition label.";
                      };
                      size = mkOption {
                        type = types.str;
                        default = "512M";
                        description = "Partition size.";
                      };
                    };
                  }
                );
                default = null;
                description = "An EFI system partition on this disk.";
              };
              content = mkOption {
                type = types.listOf subvolumeType;
                default = [ ];
                description = "The btrfs subvolumes.";
              };
            };
          }
        );
        default = { };
        description = "Disks disko formats: an optional EFI partition and one btrfs partition of subvolumes.";
      };

      config = {
        disko.devices.disk = lib.mapAttrs (name: disk: mkDisk (disk // { inherit name; })) cfg;

        fileSystems = lib.listToAttrs (
          map (sv: lib.nameValuePair (mountpointOf sv) { neededForBoot = true; }) (
            builtins.filter (sv: sv.neededForBoot) (lib.concatMap (d: d.content) (builtins.attrValues cfg))
          )
        );
      };
    };

  evalTests = {
    disko-subvolume-names = {
      expr = lib.mapAttrs (_: v: v.mountpoint) plainBtrfs.subvolumes;
      expected = {
        "@root" = "/";
        "@persist" = "/persist";
        "@swap" = "/swap";
      };
    };
    disko-btrfs-label = {
      expr = plainBtrfs.extraArgs;
      expected = [
        "-f"
        "-L root"
      ];
    };
    disko-boot-partition = {
      expr = with plainDisk.content.partitions.boot; [
        label
        size
        type
        content.mountpoint
      ];
      expected = [
        "boot"
        "1G"
        "EF00"
        "/boot"
      ];
    };
    disko-swapfile = {
      expr = plainBtrfs.subvolumes."@swap".swap.swapfile.size;
      expected = "8G";
    };
    # Guarded so formatting an already formatted disk is a no-op, as disko's
    # own install test checks by formatting twice.
    disko-blank-snapshot-guarded = {
      expr = lib.hasInfix ''[ -e "$MNTPOINT/@root-blank" ] || btrfs subvolume snapshot -r "$MNTPOINT/@root" "$MNTPOINT/@root-blank"'' plainBtrfs.postCreateHook;
      expected = true;
    };
    disko-no-snapshot-no-hook = {
      expr = encryptedParts.encrypted.content.content.postCreateHook;
      expected = "";
    };
    disko-needed-for-boot = {
      expr = plain.fileSystems."/persist".neededForBoot && !plain.fileSystems."/".neededForBoot;
      expected = true;
    };
    disko-luks = {
      expr = with encryptedParts.encrypted; [
        label
        content.type
        content.name
        content.content.type
      ];
      expected = [
        "data_encrypted"
        "luks"
        "data"
        "btrfs"
      ];
    };
    disko-no-boot-by-default = {
      expr = encryptedParts ? boot;
      expected = false;
    };
  };
}
