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

      # Off until there is somewhere off-box to back up to. Backing a laptop
      # guest up to its own disk protects against neither the loss of the host
      # Mac's disk, which both qcow2 files live on, nor a reinstall, which
      # rewrites the root disk the system itself sits on — so the two roles
      # would buy only the appearance of coverage. Disabling the server drops its
      # nginx vhost, which proxied the unauthenticated REST endpoint onto
      # whatever LAN the host Mac had joined.
      backup = disabled;
      backup-server = disabled;
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
