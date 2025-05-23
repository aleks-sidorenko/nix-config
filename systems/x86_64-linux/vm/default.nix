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
    ./hardware-configuration.nix
    ./disks.nix
  ];

  ${namespace} = {
    roles = {
      desktop = {
        enable = true;
        addons = {
          hyprland = enabled;
        };
      };
    };

    disks.impermanence = enabled;

  };

  boot = {

    kernelPackages = pkgs.linuxPackages_latest;

  };

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "25.05";
}
