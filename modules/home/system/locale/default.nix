{
  options,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.system.locale;

in
{
  options.${namespace}.system.locale = with types; {
    enable = mkBoolOpt false "Whether or not to manage locale settings of user.";
    locales =
      mkOpt (listOf str) defaults.locale.locales
        "Locales to support. First entry becomes the system locale.";
    layouts =
      mkOpt (listOf str) defaults.locale.layouts
        "Keyboard layouts to configure. First entry becomes the default layout.";
  };

  config = mkIf cfg.enable {

  };
}
