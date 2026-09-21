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
          device = "/dev/vda";
          encrypted = false;
          imageSize = "48G";
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
              name = "swap";
              swapfile.size = "4G";
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
              name = "persist";
              neededForBoot = true;
            }
          ];
        };
        data = {
          device = "/dev/vdb";
          encrypted = false;
          imageSize = "96G";
          content = [
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
      };
    };
  };
}
