{
  imports = [
    ../common/optional/ephemeral-btrfs.nix
    ../common/optional/encrypted-root.nix
  ];


  boot = {
    initrd = {
      
      # Override default /persist
      fileSystems."/persist" = {
        device = "/dev/disk/by-label/persist";
        fsType = "btrfs";
        options = [
          "subvol=persist"
          "compress=zstd"
        ];
        neededForBoot = true;
      };
    

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
    loader = {
      systemd-boot = {
        enable = true;
        consoleMode = "max";
      };
      efi.canTouchEfiVariables = true;
    };
  };

  fileSystems = {
    "/boot" = {
      device = "/dev/disk/by-label/ESP";
      fsType = "vfat";
    };
  };

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
      intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
  };
}