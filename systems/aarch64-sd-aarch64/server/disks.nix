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
          device = "/dev/sdc";
          boot = {
            size = "512M";
          };
          subvolumes = [
            {
              name = "root";
              mountpoint = "/";
              createBlankSnapshot = true;
            }
            {
              name = "swap";
              swapfile.size = "36G";
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

          ];

        };
        data = {
          device = "/dev/nvme0n1";
          subvolumes = [
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
          ];
        };
      };

    };
  };
}
