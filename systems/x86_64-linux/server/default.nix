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
    # `home-server` stays on `server-vm` until this host is bootstrapped:
    # infra/dns rejects two hosts claiming a name, so the move has to enable
    # it here and drop it there in one change.
    roles.server = enabled;

    users.alexander = {
      primary = true;
      admin = true;
    };

    disks.impermanence = enabled;
  };

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "26.05";
}
