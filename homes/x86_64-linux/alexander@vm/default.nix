{
  lib,
  namespace,
  ...
}:
with lib.${namespace};
{

  # TODO - replace with ${namespace} once this is fixed https://github.com/snowfallorg/lib/issues/142
  nix-config = {
    roles = {
      # Bare graphical suite — no development on the test VM.
      graphical = enabled;
    };

    user = {
      enable = true;
    };

    styles.stylix.wallpaper = "earth";
  };

  home.stateVersion = "25.05";
}
