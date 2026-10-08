{
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
      home-server = enabled;

      # The plugs, heatpump and climate sensors its automations name stayed
      # with the old house.
      smart-home = disabled;
    };

    users.alexander = {
      primary = true;
      admin = true;
    };

    disks.impermanence = enabled;
  };

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "25.05";
}
