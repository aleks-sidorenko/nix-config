{
  pkgs,
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
        root = {
          device = "/dev/disk/by-id/usb-Argon_Forty_000000001023-0:0";
          encrypted = false;
          boot = {
            size = "512M";
          };
          content = [
            {
              name = "root";
              mountpoint = "/";
              createBlankSnapshot = true;
            }
            {
              name = "nix";
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
            {
              name = "swap";
              swapfile.size = "4G";
            }
            {
              name = "persist";
              neededForBoot = true;
            }
            {
              name = "home";
              mountOptions = [
                "subvol=home"
                "compress=zstd"
                "noatime"
              ];
            }
          ];
        };
        data = {
          device = "/dev/disk/by-id/usb-Seagate_Expansion_NAAX0CP9-0:0";
          encrypted = false;
          content = [
            {
              name = "data";
              mountOptions = [
                "subvol=data"
                "noatime"
              ];
            }
            {
              name = "backup";
              mountOptions = [
                "subvol=backup"
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
