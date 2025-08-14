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
        system = {
          device = "/dev/mmcblk0"; # built-in eMMC, 32GB
          encrypted = false;
          boot = {
            size = "128M";
            label = "FIRMWARE";
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
          device = "/dev/sda"; # NVMe 500GB
          encrypted = false;
          content = [            
            {
              name = "persist";
              neededForBoot = true;
            }
          ];
        };
      };

    };
  };
}
