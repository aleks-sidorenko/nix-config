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
  extraLocale = head cfg.extraLocales;

in
{
  options.${namespace}.system.locale = with types; {
    enable = mkBoolOpt false "Whether or not to manage locale settings.";
    systemLocale = mkOpt str "en_US.UTF-8" "The system locale.";
    extraLocales = mkOpt (listOf str) [ "uk_UA.UTF-8" "ru_UA.UTF-8" ] "Extra locales to support.";
    layout = mkOpt str "us" "The default keyboard layout.";
    timeZone = mkOpt str "Europe/Kyiv" "The system time-zone.";
  };

  config = mkIf cfg.enable {
    i18n = {
      defaultLocale = lib.mkDefault "${systemLocale}";
      supportedLocales = lib.mkDefault [
        map
        (locale: "${locale}/UTF-8")
        cfg.extraLocales
      ];

      extraLocaleSettings = {
        # LC_ALL = "${systemLocale}"; # This overrides all other LC_* settings.
        LC_CTYPE = "${systemLocale}";
        LC_ADDRESS = "${extraLocale}";
        LC_IDENTIFICATION = "${systemLocale}";
        LC_MEASUREMENT = "${extraLocale}";
        LC_MONETARY = "${extraLocale}";
        LC_NAME = "${extraLocale}";
        LC_NUMERIC = "${extraLocale}";
        LC_PAPER = "${extraLocale}";
        LC_TELEPHONE = "${extraLocale}";
        LC_TIME = "${extraLocale}";
        LC_COLLATE = "${extraLocale}";
      };
    };
    time.timeZone = "${timeZone}";

    # Configure keymap in X11
    services.xserver = {
      xkb = {
        layout = "${layout}";
        variant = "";
      };
    };

    # Configure console keymap
    console.keyMap = "${layout}";
  };
}
