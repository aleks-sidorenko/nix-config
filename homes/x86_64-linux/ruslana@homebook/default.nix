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
      homebook = enabled;
      communication = enabled;
    };

    styles.stylix.wallpaper = "pizza";

    user = {
      enable = true;
      name = "ruslana";
    };
  };

  home.stateVersion = "25.05";
}
