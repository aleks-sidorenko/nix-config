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
    # A test guest now that `server` runs `home-server`. infra/dns rejects two
    # hosts claiming a service name, so it carries no service roles.
    roles.common = enabled;

    # Kept so it still joins unattended: an OAuth-key registration with no
    # tags is rejected, and `tag:server` came from the role dropped above.
    services.networking.tailscale.tags = [ "tag:server" ];

    users.alexander = {
      primary = true;
      admin = true;
    };

    disks.impermanence = enabled;
  };

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "25.05";
}
