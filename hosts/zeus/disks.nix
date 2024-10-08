{ config, lib, pkgs, ... }:
{
  imports = [
    ../common/disks {disk = "/dev/sdc", swapSize = 33 }
  ];

 # TODO - remove persist from disko.main.* and add to disko.extra.*

  boot.initrd.luks.devices."persist".device = "/dev/disk/by-label/persist_crypt";
  fileSystems."/persist".device = lib.mkForce "/dev/disk/by-label/persist";
  
  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 33792; # 33G
    }
  ];

