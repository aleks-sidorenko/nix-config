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
          imageSize = "64G";
          content = [
            # Deliberate divergence from the Pi, which keeps `home` on the root
            # disk. A guest is reinstalled far more readily than a machine you
            # have to carry install media to, and a reinstall runs disko over
            # /dev/vda only — so everything on this second disk survives it,
            # while anything on root does not.
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
