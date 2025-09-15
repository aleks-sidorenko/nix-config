{
  pkgs,
  config,
  lib,
  namespace,
  inputs,
  options,
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

      kernelPackages = pkgs.linuxPackages_latest;

      kernelParams = [
        "console=ttyS0,115200n8"
        "console=ttyAMA0,115200n8"
        "console=tty0"
        "cma=64M"
      ];

      initrd.availableKernelModules = [
        # Allows early (earlier) modesetting for the Raspberry Pi
        "vc4"
        "bcm2835_dma"
        "i2c_bcm2835"

        # Maybe needed for SSD boot?
        "usb_storage"
        "xhci_pci"
        "usbhid"
        "uas"
      ];

      supportedFilesystems = [ "btrfs" ];
    };
    powerManagement.cpuFreqGovernor = "ondemand";

    environment.systemPackages = with pkgs; [
      libraspberrypi
      raspberrypi-eeprom
    ];
  };
}
