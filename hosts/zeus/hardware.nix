{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [
    ../common/optional/ephemeral-btrfs.nix
    ../common/optional/encrypted-root.nix
  ];


  boot = {
    initrd = {


      # Additional persist device      
      luks.devices."persist".device = "/dev/disk/by-label/persist_crypt";
      
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "ahci"
        "usb_storage"
        "usbhid"
        "sd_mod"
      ];
      kernelModules = ["kvm-intel"];
    };
    
  };

  fileSystems."/persist".device = lib.mkForce "/dev/disk/by-label/persist";
  
  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 33792; # 33G
    }
  ];

  nixpkgs.hostPlatform.system = "x86_64-linux";
  
  hardware = { 
    enableAllFirmware = true;
    graphics.enable = true;
    cpu = {
      intel.updateMicrocode = config.hardware.enableRedistributableFirmware;
    };
  };
}