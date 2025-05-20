{ lib, namespace, ... }:
{
  ${namespace} = {

    services = {
      openssh.enable = true;
    };

    system = {
      locale.enable = true;
      networking.enable = true;
      nix.enable = true;
    };

    user = {
      name = "nixos";
      initialPassword = "nixos";
    };

  };

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "25.05";
}
