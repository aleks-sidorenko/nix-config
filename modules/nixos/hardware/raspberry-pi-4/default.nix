{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.hardware.raspberry-pi-4;
in
{
  options.${namespace}.hardware.raspberry-pi-4 = {
    enable = mkEnableOption "Enable The raspberry-pi-4 config";
  };

  # https://nixos.wiki/wiki/NixOS_on_ARM/Raspberry_Pi
  # https://nixos.wiki/wiki/NixOS_on_ARM/Raspberry_Pi_4
  config = mkIf cfg.enable {
    ${namespace}.disks.boot.enable = mkForce false;

    boot = {
      loader = {
        grub.enable = mkForce false;
        generic-extlinux-compatible.enable = true;
      };

      kernelPackages = mkForce pkgs.linuxPackages_rpi4;
      kernelParams = [
        "cgroup_memory=1"
        "cgroup_enable=cpuset"
        "cgroup_enable=memory"
        "cma=64M"
      ];
      supportedFilesystems = [ "btrfs" ];

      initrd = {
        kernelModules = [
          "zstd"
          "btrfs"
        ];
        availableKernelModules = [
          "xhci_pci"
        ];
      };
    };

    hardware = {
      enableRedistributableFirmware = true;
      firmware = [ pkgs.wireless-regdb ];

      raspberry-pi."4" = {
        fkms-3d.enable = false;
      };
      graphics.enable = false;
    };

    sdImage.compressImage = false;
  };
}
