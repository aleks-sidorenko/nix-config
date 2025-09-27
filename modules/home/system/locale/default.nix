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
    locale = mkOpt str "en_US.UTF-8" "The user locale.";
    layout = mkOpt str "us,ua,ru" "The user keyboard layouts (comma-separated).";
    layoutOptions = mkOpt str "grp:lwin_toggle" "Keyboard layout switching options.";
  };

  config = mkIf cfg.enable {

  };
}
