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
