{ lib, namespace, ... }:
{
  ${namespace} = {
    nix.enable = true;
    services = {
      openssh.enable = true;
    };

    system = {
      locale.enable = true;
      networking.enable = true;
    };

    user = {
      name = "nixos";
      initialPassword = "nixos";
    };
    
  };

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "25.05";
}
