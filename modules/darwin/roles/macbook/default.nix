{
  lib,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.macbook;
in
{
  options.${namespace}.roles.macbook = with types; {
    enable = mkEnableOption "Enable macbook configuration";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      # Inherit common configuration
      roles.common = {
        enable = true;
        homebrew = {
          taps = [
          ];
          brews = [
            "mas" # Mac App Store CLI
          ];
          casks = [
            "raycast" # Spotlight replacement
          ];
        };
      };

      desktops.aerospace = enabled;

      communication = {
        viber = enabled;
        telegram = enabled;
      };

      browsers = {
        chromium = enabled;
      };

    };
  };
}
