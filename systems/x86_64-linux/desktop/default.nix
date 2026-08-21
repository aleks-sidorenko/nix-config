{
  pkgs,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
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
      agent-host = enabled;
    };

    styles.stylix.wallpaper = "Kurzgesagt-Galaxies";
  };

  boot = {
    # There is issue with latest 6.19 kernel & nvidia drivers https://github.com/nixos/nixpkgs/issues/489947
    # TODO - move to latest once it is resolved
    kernelPackages = pkgs.linuxPackages_6_18; # pkgs.linuxPackages_latest;
  };

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "25.05";
}
