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
      macbook = enabled;
    };

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
      ];
    };

    user = {
      enable = true;
    };

    styles.stylix.wallpaper = "earth";
  };

  home.stateVersion = "25.05";
}
