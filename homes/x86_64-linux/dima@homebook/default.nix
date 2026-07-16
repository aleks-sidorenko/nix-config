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
      child = enabled;
    };

    styles.stylix.wallpaper = "Kurzgesagt-Galaxy_3";

    user = {
      enable = true;
      name = "dima";
    };
  };

  home.stateVersion = "25.05";
}
