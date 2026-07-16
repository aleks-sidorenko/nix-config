{
  config,
  lib,
  modulesPath,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  ${namespace} = {
    hardware = {
      audio.enable = true;
      bluetooth.enable = true;
    };
  };

  boot = {
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "nvme"
        "usb_storage"
        "sd_mod"
        "rtsx_usb_sdmmc"
      ];
      kernelModules = [ "kvm-intel" ];
    };
  };

  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };
}
