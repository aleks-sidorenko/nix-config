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
  locale = cfg.locale;
  layout = cfg.layout;
  timeZone = cfg.timeZone;

in
{
  options.${namespace}.system.locale = with types; {
    enable = mkBoolOpt false "Whether or not to manage locale settings.";
    locale = mkOpt str "en_US.UTF-8" "The system locale.";
    layout = mkOpt str "us,ua,ru" "The keyboard layouts (comma-separated).";
    layoutOptions = mkOpt str "grp:lwin_toggle" "Keyboard layout switching options.";
    timeZone = mkOpt str "Europe/Kyiv" "The system time-zone.";
  };

  config = mkIf cfg.enable {
    i18n = {
      defaultLocale = lib.mkDefault "${locale}";

      extraLocaleSettings = {
        LC_ADDRESS = "${locale}";
        LC_IDENTIFICATION = "${locale}";
        LC_MEASUREMENT = "${locale}";
        LC_MONETARY = "${locale}";
        LC_NAME = "${locale}";
        LC_NUMERIC = "${locale}";
        LC_PAPER = "${locale}";
        LC_TELEPHONE = "${locale}";
        LC_TIME = "${locale}";
      };
    };
    time.timeZone = "${timeZone}";

    # Configure keymap in X11
    services.xserver = {
      xkb = {
        layout = "${layout}";
        variant = "";
        options = "${cfg.layoutOptions}";
      };
    };

    # Configure console keymap - use first layout for console
    console.keyMap = lib.mkDefault (lib.head (lib.splitString "," layout));
  };
}
