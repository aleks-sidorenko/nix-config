{
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
{
  ${namespace} = {

    roles.minimal = enabled;

    # SSH is key-based (password auth disabled). The primary user here is the
    # throwaway `nixos` account with no identity, so the ssh module falls back
    # to authorizing the owner identity — the operator can SSH in to bootstrap,
    # while the local console still logs in as nixos/nixos.
    users.nixos = {
      primary = true;
      admin = true;
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
