{ inputs, lib, ... }:
let
  inherit (lib) mkOption types;

  label = "root";
  defaultMountOptions = [
    "compress=zstd"
    "noatime"
  ];

  subvolumes =
    swapSize:
    lib.mapAttrs (_: subvolume: { mountOptions = defaultMountOptions; } // subvolume) {
      "@root".mountpoint = "/";
      "@nix".mountpoint = "/nix";
      "@log" = {
        mountpoint = "/var/log";
        mountOptions = [ "subvol=log" ] ++ defaultMountOptions;
      };
      "@swap" = {
        mountpoint = "/swap";
        swap.swapfile.size = swapSize;
      };
      "@persist".mountpoint = "/persist";
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

  btrfs = cfg: {
    type = "btrfs";
    extraArgs = [
      "-f"
      "-L ${label}"
    ];
    # Taken whether or not the host is impermanent, so it can become so later.
    postCreateHook = ''
      mkdir -p /tmp
      MNTPOINT=$(mktemp -d)
      mount -t btrfs /dev/disk/by-label/${label} "$MNTPOINT"
      trap 'umount "$MNTPOINT"; rm -rf "$MNTPOINT"' EXIT
      btrfs subvolume snapshot -r "$MNTPOINT/@root" "$MNTPOINT/@root-blank"
    '';
    subvolumes = subvolumes cfg.swapSize;
  };

  # Attribute names are part of the layout: renaming one changes the partition.
  rootPartition =
    cfg:
    if cfg.encrypted then
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
            content = btrfs cfg;
          };
        };
      }
    else
      {
        btrfs = {
          size = "100%";
          inherit label;
          content = btrfs cfg;
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
      { host, ... }:
      let
        cfg = host.settings.storage.disko;
      in
      {
        imports = [ inputs.disko.nixosModules.disko ];

        disko.devices.disk.root = {
          type = "disk";
          inherit (cfg) device;
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
            // rootPartition cfg;
          };
        };

        fileSystems = lib.genAttrs [ "/var/log" "/persist" ] (_: {
          neededForBoot = true;
        });
      };
  };
}
