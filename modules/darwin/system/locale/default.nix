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
  locales = cfg.locales;
  systemLocale = head locales;
  extraLocales = tail locales;
  nativeLocale = if extraLocales == [ ] then systemLocale else head extraLocales;
  timeZone = cfg.timeZone;
in
{
  options.${namespace}.system.locale = with types; {
    enable = mkBoolOpt false "Whether or not to manage locale settings";
    locales =
      mkOpt (listOf str) defaults.locale.locales
        "Locales to support. First entry becomes the system locale";
    layouts =
      mkOpt (listOf str) defaults.locale.layouts
        "Keyboard layouts to configure (managed via System Preferences on macOS)";
    timeZone = mkOpt str defaults.locale.timeZone "The system time-zone";
  };

  config = mkIf cfg.enable {
    time.timeZone = timeZone;

    # Set locale environment variables
    environment.variables = {
      LANG = systemLocale;
      LC_CTYPE = systemLocale;
      LC_ADDRESS = nativeLocale;
      LC_IDENTIFICATION = systemLocale;
      LC_MEASUREMENT = nativeLocale;
      LC_MONETARY = nativeLocale;
      LC_NAME = nativeLocale;
      LC_NUMERIC = nativeLocale;
      LC_PAPER = nativeLocale;
      LC_TELEPHONE = nativeLocale;
      LC_TIME = nativeLocale;
      LC_COLLATE = nativeLocale;
    };
  };
}
