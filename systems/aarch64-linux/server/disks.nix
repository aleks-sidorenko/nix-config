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
            label = "FIRMWARE";
            mountpoint = "/boot/firmware";
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
      };
    };
  };
}