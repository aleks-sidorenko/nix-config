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
    # to authorizing the owner identity — the operator can SSH in to bootstrap.
    users.nixos = {
      primary = true;
      admin = true;
    };

  };

  # No password is set for `nixos` here: SOPS is disabled on the installer, so
  # the users module leaves the account password-less, and the stock
  # installation-device profile provides a passwordless console autologin.

  isoImage = {
    isoName = "nixos-minimal";
    forceTextMode = true;
  };

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "25.05";
}
