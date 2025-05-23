{ lib, namespace, ... }:
{
  ${namespace} = {

    security = {
      ssh.enable = true;
    };

    system = {
      locale.enable = true;
      networking.enable = true;
      nix.enable = true;
    };

    cli = {
      shells.fish.enable = true;
    };

    user = {
      name = "nixos";
      initialPassword = "nixos";
    };

  };

  isoImage = {
    isoName = "nixos-minimal";
    forceTextMode = true;
  };

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "25.05";
}
