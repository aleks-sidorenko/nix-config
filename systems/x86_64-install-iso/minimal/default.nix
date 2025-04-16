{ lib, namespace, ... }:
{
  ${namespace} = {
    nix.enable = true;
    services = {
      openssh.enable = true;
    };

    system = {
      locale.enable = true;
    };

    user = {
      name = "nixos";
      initialPassword = "nixos";
    };
    hardware.networking = {
      enable = true;

    };
  };

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "25.05";
}
