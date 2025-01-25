{
  pkgs,
  lib,
  namespace
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./disks.nix
  ];

  environment.pathsToLink = ["/share/fish"];
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;

  services = {
    virtualisation.kvm.enable = true;
    hardware.openrgb.enable = true;
    ${namespace}.nfs.enable = true;
  };
  programs.coolercontrol.enable = true;
  hardware.amdgpu.opencl.enable = true;

  roles = {    
    desktop = {
      enable = true;
      addons = {
        hyprland.enable = true;
      };
    };
  };

  boot = {
    # FIXME: validate offset
    kernelParams = [
      "resume_offset=533760"
    ];
    blacklistedKernelModules = [
      "ath12k_pci"
      "ath12k"
    ];

    supportedFilesystems = lib.mkForce ["btrfs"];
    kernelPackages = pkgs.linuxPackages_latest;
    # FIXME: validate label after disko
    resumeDevice = "/dev/disk/by-label/nixos";

    initrd = {
      supportedFilesystems = ["nfs"];
      kernelModules = ["nfs"];
    };
  };

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "24.11";
}
