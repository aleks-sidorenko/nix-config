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
          device = "/dev/sda";
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
      };

    };
  };
}
