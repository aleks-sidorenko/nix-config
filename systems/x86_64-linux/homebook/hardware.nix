# TODO: PLACEHOLDER — replace with the output of `nixos-generate-config` run on
# the real homebook machine (kernel modules, microcode vendor, video driver).
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
      # TODO: confirm against the real machine.
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "ahci"
        "usb_storage"
        "usbhid"
        "sd_mod"
      ];
      kernelModules = [ ];
    };
  };

  hardware = {
    # TODO: switch to `cpu.amd.updateMicrocode` if the laptop is AMD.
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };
}
