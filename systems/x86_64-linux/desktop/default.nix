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


  ${namespace} = {
    roles = {
      desktop = {
        enable = true;
        addons = {
          hyprland.enable = true;
        };
      };
    };

    services = {
      virtualisation.kvm = enabled;
    };

    system.impermanence = enabled;

  };


  services = {    
    hardware.openrgb.enable = true;    
  };
  
  programs.coolercontrol.enable = true;

  
  boot = {
    
    kernelParams = [
      "resume_offset=533760"
    ];

    resumeDevice = "/dev/disk/by-label/root";
    
    blacklistedKernelModules = [
      "ath12k_pci"
      "ath12k"
    ];

    supportedFilesystems = lib.mkForce ["btrfs"];
    kernelPackages = pkgs.linuxPackages_latest;
    
    

    initrd = {
      supportedFilesystems = ["nfs"];
      kernelModules = ["nfs"];
    };
  };

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "24.11";
}
