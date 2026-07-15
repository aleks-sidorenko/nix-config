# Unencrypted (no LUKS) BTRFS + impermanence layout for the shared laptop.
# TODO: PLACEHOLDER — replace `device` with the real `/dev/disk/by-id/...` path
# from the target machine before bootstrapping.
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
          device = "/dev/disk/by-id/REPLACE-ME"; # TODO
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
