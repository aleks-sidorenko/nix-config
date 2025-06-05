{
  pkgs,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let

in
{
  imports = [
    ./hardware.nix
    ./disks.nix
  ];

  ${namespace} = {
    roles = {
      desktop = {
        enable = true;
      };
    };

    security.sops.enable = mkForce false;

    services = {
      virtualisation.kvm = enabled;
    };

  };

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
  };

  # Allow unfree packages and accept NVIDIA license
  nixpkgs.config = {
    allowUnfree = true;
    nvidia.acceptLicense = true;
  };

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "25.05";
}
