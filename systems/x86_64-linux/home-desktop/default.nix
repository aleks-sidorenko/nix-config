{
  pkgs,
  lib,
  namespace,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./disks.nix
  ];

  system.boot.plymouth = lib.mkForce false;

  system.impermanence.enable = true;

  services = {
    virtualisation.kvm.enable = true;
    hardware.openrgb.enable = true;    
  };
  
  programs.coolercontrol.enable = true;

  roles = {    
    desktop = {
      enable = true;
      addons = {
        hyprland.enable = true;
      };
    };
  };

  boot = {
    
    kernelParams = [
      "resume_offset=533760"
    ];
    blacklistedKernelModules = [
      "ath12k_pci"
      "ath12k"
    ];

    supportedFilesystems = lib.mkForce ["btrfs"];
    kernelPackages = pkgs.linuxPackages_latest;
    
    resumeDevice = "/dev/disk/by-label/root";

    initrd = {
      supportedFilesystems = ["nfs"];
      kernelModules = ["nfs"];
    };
  };

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "24.11";
}
