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
    roles.work = enabled;

    desktops.monitors = {
      enable = true;
      devices = [
        {
          name = "built-in";
          model = "Built-in Retina Display";
          width = 3024;
          height = 1964;
          primary = true;
          workspaces = [
            "1"
            "2"
            "3"
            "4"
            "5"
          ];
        }
        {
          name = "external";
          model = "DELL U2419H";
          width = 1920;
          height = 1080;
          workspaces = [
            "6"
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

    styles.stylix.wallpaper = "earth";
  };

  home.stateVersion = "25.05";
}
