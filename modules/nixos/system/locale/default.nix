{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.system.locale;
  inherit (cfg) locales;
  systemLocale = head locales;
  extraLocales = tail locales;
  nativeLocale = if extraLocales == [ ] then systemLocale else head extraLocales;
  inherit (cfg) layouts;
  systemLayout = head layouts;
  inherit (cfg) timeZone;
  xkbLayout = concatStringsSep "," layouts;
  xkbOptions = "grp:win_space_toggle";

in
{
  options.${namespace}.system.locale = with types; {
    enable = mkBoolOpt false "Whether or not to manage locale settings";
    locales =
      mkOpt (listOf str) defaults.locale.locales
        "Locales to support. First entry becomes the system locale";
    layouts =
      mkOpt (listOf str) defaults.locale.layouts
        "Keyboard layouts to configure. First entry becomes the default layout";
    timeZone = mkOpt str defaults.locale.timeZone "The system time-zone";
  };

  config = mkIf cfg.enable {
    i18n = {
      defaultLocale = lib.mkDefault "${systemLocale}";
      supportedLocales = lib.mkDefault (map (locale: "${locale}/UTF-8") locales);

      extraLocaleSettings = {
        # LC_ALL = "${systemLocale}"; # This overrides all other LC_* settings.
        LC_CTYPE = "${systemLocale}";
        LC_ADDRESS = "${nativeLocale}";
        LC_IDENTIFICATION = "${systemLocale}";
        LC_MEASUREMENT = "${nativeLocale}";
        LC_MONETARY = "${nativeLocale}";
        LC_NAME = "${nativeLocale}";
        LC_NUMERIC = "${nativeLocale}";
        LC_PAPER = "${nativeLocale}";
        LC_TELEPHONE = "${nativeLocale}";
        LC_TIME = "${nativeLocale}";
        LC_COLLATE = "${nativeLocale}";
      };
    };
    time.timeZone = "${timeZone}";

    # Configure keymap in X11
    services.xserver = {
      xkb = {
        layout = "${xkbLayout}";
        options = "${xkbOptions}";
        variant = "";
      };
    };

    # Configure console keymap
    console.keyMap = "${systemLayout}";
  };
}
