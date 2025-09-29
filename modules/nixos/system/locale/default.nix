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
  locales = cfg.locales;
  systemLocale = head locales;
  locale = systemLocale;
  extraLocales = tail locales;
  extraLocale = head extraLocales;
  layouts = cfg.layouts;
  layout = head layouts;
  extraLayouts = tail layouts;
  timeZone = cfg.timeZone;
  xkbLayout = concatStringsSep "," layouts;
  inputSources = map (layoutValue: {
    type = "xkb";
    layout = layoutValue;
  }) layouts;
  xkbOptions = "grp:win_space_toggle";

in
{
  options.${namespace}.system.locale = with types; {
    enable = mkBoolOpt false "Whether or not to manage locale settings.";
    locales =
      mkOpt (listOf str) defaults.locale.locales
        "Locales to support. First entry becomes the system locale.";
    layouts =
      mkOpt (listOf str) defaults.locale.layouts
        "Keyboard layouts to configure. First entry becomes the default layout.";
    timeZone = mkOpt str defaults.locale.timeZone "The system time-zone.";
  };

  config = mkIf cfg.enable {
    i18n = {
      defaultLocale = lib.mkDefault "${locale}";
      supportedLocales = lib.mkDefault (map (locale: "${locale}/UTF-8") locales);

      extraLocaleSettings = {
        # LC_ALL = "${locale}"; # This overrides all other LC_* settings.
        LC_CTYPE = "${locale}";
        LC_ADDRESS = "${extraLocale}";
        LC_IDENTIFICATION = "${locale}";
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
        layout = "${xkbLayout}";
        options = "${xkbOptions}";
        variant = "";
      };
    };

    # Configure console keymap
    console.keyMap = "${layout}";
  };
}
