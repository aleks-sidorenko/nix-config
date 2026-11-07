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
        root = {
          device = "/dev/disk/by-id/ata-SSD_2TB_004208";
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
              swapfile.size = "8G";
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
            {
              name = "data";
              mountOptions = [
                "subvol=data"
                "noatime"
              ];
            }
          ];
        };
      };
    };
  };
}
