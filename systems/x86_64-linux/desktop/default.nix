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

  
  boot = {
    
    kernelPackages = pkgs.linuxPackages_latest;
    
  };

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "24.11";
}
