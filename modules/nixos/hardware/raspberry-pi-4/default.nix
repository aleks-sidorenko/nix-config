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

  config = mkIf cfg.enable {
    boot = {
      kernelPackages = pkgs.linuxPackages_rpi4;
      kernelParams = [
        "cgroup_memory=1"
        "cgroup_enable=cpuset"
        "cgroup_enable=memory"
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

    # Raspberry Pi 4 specific firmware mount
    # Mount the boot partition (labeled "boot" by disko) as /firmware for Pi firmware access
    fileSystems."/firmware" = {
      device = "/dev/disk/by-label/boot";
      fsType = "vfat";
      options = [ "defaults" ];
      neededForBoot = true;
    };

    hardware = {
      enableRedistributableFirmware = true;      
    };
  };
}
