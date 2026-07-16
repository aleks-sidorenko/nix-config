# Unencrypted (no LUKS) BTRFS + impermanence layout for the shared laptop.
{
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
{
  ${namespace} = {
    disks.disko = {
      enable = true;
      disks = {
        # Must be named `root` so the impermanence rollback service can mount
        # `by-label/root` (see lib/defaults: disks.root = "root").
        root = {
          device = "/dev/disk/by-id/nvme-SAMSUNG_MZVLW256HEHP-00000_S33VNX0K403335";
          encrypted = false;
          boot = {
            size = "1G";
          };
          content = [
            {
              name = "root";
              mountpoint = "/";
              createBlankSnapshot = true;
            }
            {
              name = "swap";
              swapfile.size = "16G";
            }
            {
              name = "nix";
            }
            {
              name = "home";
              mountOptions = [
                "subvol=home"
                "compress=zstd"
                "noatime"
              ];
            }
            {
              name = "persist";
              neededForBoot = true;
            }
            {
              name = "log";
              mountpoint = "/var/log";
              neededForBoot = true;
              mountOptions = [
                "subvol=log"
                "compress=zstd"
                "noatime"
              ];
            }
          ];
        };
      };
    };
  };
}
