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

    styles.stylix.wallpaper = "Kurzgesagt-Galaxy_3";

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

  # Do not change this value! This tracks when NixOS was installed on your system.
  system.stateVersion = "25.05";
}
