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

      # Nothing here is worth keeping: the root image is rebuilt on demand and
      # the data disk is a media cache, not a source of record.
      backup = disabled;
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

  # Breaks the first-boot deadlock: the guest is not a sops recipient until it
  # has generated a host key, so its accounts stay locked and there is no
  # password to answer a sudo prompt with. Without this, deploy-rs asks for one
  # and the only way forward is re-imaging, which discards the host key again.
  security.sudo.wheelNeedsPassword = false;

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "25.05";
}
