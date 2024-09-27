{config, ...}: let
  device = "root";
in {
  boot.initrd = {
    luks.devices."${device}".device = "/dev/disk/by-label/${device}_crypt";
  };
}