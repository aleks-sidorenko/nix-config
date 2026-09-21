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
      graphical = enabled;

      # The gaming suite is x86-only (hardware.graphics.enable32Bit).
      gaming = disabled;
    };

    users.alexander = {
      primary = true;
      admin = true;
    };

    disks.impermanence = enabled;

    # Bridged addressing follows whichever LAN the host Mac is on, so the
    # tailnet carries the guest's stable identity.
    services.networking.tailscale = enabled;

    # Hibernation is meaningless in a guest.
    system.hibernation.enable = false;
  };

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "25.05";
}
