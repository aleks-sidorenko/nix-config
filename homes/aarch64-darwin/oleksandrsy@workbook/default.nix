{
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
{
  # TODO - replace with ${namespace} once this is fixed https://github.com/snowfallorg/lib/issues/142
  nix-config = {
    roles = {
      work = enabled;
    };

    desktops.monitors = {
      enable = true;
      devices = [
        {
          name = "external";
          model = "Mi monitor";
          width = 3440;
          height = 1440;
          refreshRate = 180;
          workspaces = [
            "1"
            "2"
            "3"
            "4"
            "5"
            "6"
          ];
        }
        {
          name = "built-in";
          model = "Built-in Retina Display";
          width = 3456;
          height = 2234;
          primary = true;
          workspaces = [
            "7"
            "8"
            "9"
            "10"
          ];
        }
      ];
    };

    user = {
      enable = true;
      name = mkForce "oleksandrsy";
    };

    # The oleksandrsy account is the same person as `alexander`; reuse that
    # identity's key material (identities/alexander/).
    security.identity.name = "alexander";

    # Endpoint security on this managed host kills the qbittorrent process.
    media.qbittorrent.enable = mkForce false;

    games.minecraft = enabled;

    styles.stylix.wallpaper = "earth";
  };

  home.stateVersion = "25.05";
}
