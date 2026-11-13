{ inputs, lib, ... }:
let
  inherit (lib) mkOption types;

  layout = import ./_layout.nix;
  inherit (layout) label;
  defaultMountOptions = [
    "compress=zstd"
    "noatime"
  ];

  # `neededForBoot` is ours, not disko's: it is stripped before disko sees the table.
  subvolumes =
    host:
    lib.mapAttrs (_: subvolume: { mountOptions = defaultMountOptions; } // subvolume) {
      ${layout.root}.mountpoint = "/";
      "@nix".mountpoint = "/nix";
      "@log" = {
        mountpoint = "/var/log";
        mountOptions = [ "subvol=log" ] ++ defaultMountOptions;
        neededForBoot = true;
      };
      "@swap" = {
        mountpoint = "/swap";
        swap.swapfile.size = host.settings.storage.disko.swapSize;
      };
      "@persist" = {
        mountpoint = host.settings.storage.impermanence.root;
        neededForBoot = true;
      };
      "@home" = {
        mountpoint = "/home";
        mountOptions = [ "subvol=home" ] ++ defaultMountOptions;
      };
      "@data" = {
        mountpoint = "/data";
        mountOptions = [
          "subvol=data"
          "noatime"
        ];
      };
    };

  btrfs = host: {
    type = "btrfs";
    extraArgs = [
      "-f"
      "-L ${label}"
    ];
    # Taken whether or not the host is impermanent, so it can become so later.
    # Guarded because a re-format would otherwise snapshot into the existing
    # read-only blank and fail.
    postCreateHook = ''
      mkdir -p /tmp
      MNTPOINT=$(mktemp -d)
      mount -t btrfs /dev/disk/by-label/${label} "$MNTPOINT"
      trap 'umount "$MNTPOINT"; rm -rf "$MNTPOINT"' EXIT
      btrfs subvolume show "$MNTPOINT/${layout.blank}" >/dev/null 2>&1 || btrfs subvolume snapshot -r "$MNTPOINT/${layout.root}" "$MNTPOINT/${layout.blank}"
    '';
    subvolumes = lib.mapAttrs (_: subvolume: removeAttrs subvolume [ "neededForBoot" ]) (
      subvolumes host
    );
  };

  # Attribute names are part of the layout: renaming one changes the partition.
  rootPartition =
    host:
    if host.settings.storage.disko.encrypted then
      {
        encrypted = {
          size = "100%";
          label = "${label}_encrypted";
          content = {
            type = "luks";
            name = label;
            # Read only while installing; at boot the key comes from FIDO2 or a prompt.
            passwordFile = "/tmp/disk.key";
            settings = {
              allowDiscards = true;
              crypttabExtraOpts = [
                "fido2-device=auto"
                "token-timeout=10"
              ];
            };
            content = btrfs host;
          };
        };
      }
    else
      {
        btrfs = {
          size = "100%";
          inherit label;
          content = btrfs host;
        };
      };
in
{
  flake-file.inputs.disko = {
    url = "github:nix-community/disko";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.storage.disko = {
    settings = {
      device = mkOption {
        type = types.str;
        description = "Disk to lay out, e.g. /dev/disk/by-id/…";
      };
      swapSize = mkOption {
        type = types.str;
        default = "8G";
        description = "Size of the swapfile.";
      };
      encrypted = mkOption {
        type = types.bool;
        default = true;
        description = "Put the btrfs filesystem inside LUKS.";
      };
    };

    nixos =
      { host, installChecks, ... }:
      {
        imports = [ inputs.disko.nixosModules.disko ];

        disko.tests.extraChecks = lib.concatLines installChecks;

        disko.devices.disk.root = {
          type = "disk";
          inherit (host.settings.storage.disko) device;
          content = {
            type = "gpt";
            partitions = {
              boot = {
                priority = 1;
                label = "boot";
                size = "1G";
                type = "EF00";
                content = {
                  type = "filesystem";
                  extraArgs = [ "-nboot" ];
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [ "umask=0077" ];
                };
              };
            }
            // rootPartition host;
          };
        };

        fileSystems = lib.mapAttrs' (
          _: subvolume: lib.nameValuePair subvolume.mountpoint { neededForBoot = true; }
        ) (lib.filterAttrs (_: subvolume: subvolume.neededForBoot or false) (subvolumes host));
      };
  };
}
