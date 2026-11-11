# Written out to match what master's generic disko builder rendered for this
# disk, so a deploy over the live machine sees the same layout.
let
  subvolume = name: mountpoint: mountOptions: { inherit name mountpoint mountOptions; };
  zstd = [
    "compress=zstd"
    "noatime"
  ];
in
{
  disko.devices.disk.root = {
    type = "disk";
    device = "/dev/disk/by-id/ata-SSD_2TB_004208";
    content = {
      type = "gpt";
      partitions = {
        boot = {
          label = "boot";
          size = "1G";
          type = "EF00";
          priority = 1;
          content = {
            type = "filesystem";
            format = "vfat";
            extraArgs = [ "-nboot" ];
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        btrfs = {
          label = "root";
          size = "100%";
          content = {
            type = "btrfs";
            # The label is what the impermanence rollback mounts by.
            extraArgs = [
              "-f"
              "-L root"
            ];
            # The read-only snapshot the rollback restores @root from. Guarded so
            # formatting an already formatted disk is a no-op, as disko expects.
            postCreateHook = ''
              mkdir -p /tmp
              MNTPOINT=$(mktemp -d)
              mount -t btrfs /dev/disk/by-label/root "$MNTPOINT"
              trap 'umount "$MNTPOINT"; rm -rf "$MNTPOINT"' EXIT
              echo "Creating blank snapshot of @root"
              [ -e "$MNTPOINT/@root-blank" ] || btrfs subvolume snapshot -r "$MNTPOINT/@root" "$MNTPOINT/@root-blank"

            '';
            subvolumes = {
              "@root" = subvolume "@root" "/" zstd;
              "@nix" = subvolume "@nix" "/nix" zstd;
              "@log" = subvolume "@log" "/var/log" ([ "subvol=log" ] ++ zstd);
              "@swap" = subvolume "@swap" "/swap" zstd // {
                swap.swapfile.size = "8G";
              };
              "@persist" = subvolume "@persist" "/persist" zstd;
              "@home" = subvolume "@home" "/home" ([ "subvol=home" ] ++ zstd);
              "@data" = subvolume "@data" "/data" [
                "subvol=data"
                "noatime"
              ];
            };
          };
        };
      };
    };
  };

  fileSystems = {
    "/persist".neededForBoot = true;
    "/var/log".neededForBoot = true;
  };
}
