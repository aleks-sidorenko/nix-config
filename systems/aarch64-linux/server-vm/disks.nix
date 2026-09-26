{
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
{
  # Raw images are sparse in the builder, but that sparseness does not survive
  # the NAR transfer into /nix/store, so a raw 48G+64G build writes ~112G twice
  # (store + destination). qcow2 is thin-provisioned end to end; imageSize
  # above stays a virtual cap, not a real allocation.
  disko.imageBuilder.imageFormat = "qcow2";

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
          device = "/dev/vdb";
          encrypted = false;
          imageSize = "64G";
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
