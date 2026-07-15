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
      homebook = enabled;
    };

    # Shared family laptop: primary admin plus an 8-year-old child account
    # restricted to Minecraft (see the `child` home role for dima@homebook).
    users = {
      alexander = {
        primary = true;
        admin = true;
      };
      dima = {
        profile = "child";
      };
    };
  };

  # Needed for chrome/media packages pulled in by the desktop home composition.
  nixpkgs.config.allowUnfree = true;

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "25.05";
}
