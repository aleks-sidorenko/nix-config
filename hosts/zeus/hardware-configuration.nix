{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot = {
    supportedFilesystems = [ "btrfs" ];
    initrd = {
      availableKernelModules =  [ "ehci_pci" "ahci" "nvme" "xhci_pci" "firewire_ohci" "usb_storage" "usbhid" "sd_mod" ];
      kernelModules = [ "dm-snapshot" ];
      root = {
        # Use https://nixos.wiki/wiki/Full_Disk_Encryption
        device = "/dev/disk/by-uuid/f599c8ce-2644-4593-a4e8-75b02507d41a";
        preLVM = true;
      };
    };
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };
  

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/2a95bf66-b886-44e7-969b-2b1874ebe707";
      fsType = "btrfs";
      options = [ "subvol=root" "compress=zstd" "noatime" ];
    };

  fileSystems."/home" =
    { device = "/dev/disk/by-uuid/2a95bf66-b886-44e7-969b-2b1874ebe707";
      fsType = "btrfs";
      options = [ "subvol=home" "compress=zstd" "noatime" ];
    };

  fileSystems."/nix" =
    { device = "/dev/disk/by-uuid/2a95bf66-b886-44e7-969b-2b1874ebe707";
      fsType = "btrfs";
      options = [ "subvol=nix" "compress=zstd" "noatime" ];
    };

  fileSystems."/persist" =
    { device = "/dev/disk/by-uuid/2a95bf66-b886-44e7-969b-2b1874ebe707";
      fsType = "btrfs";
      options = [ "subvol=persist" "compress=zstd" "noatime" ];
    };

  fileSystems."/var/log" =
    { device = "/dev/disk/by-uuid/2a95bf66-b886-44e7-969b-2b1874ebe707";
      fsType = "btrfs";
      options = [ "subvol=log" "compress=zstd" "noatime" ];
      neededForBoot = true;
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/7613-F27B";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/3107c334-cbb0-4675-b1c1-1c79fe91d12d"; }
    ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware = { 
    enableAllFirmware = true;
    cpu = {
      intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
  };
}

