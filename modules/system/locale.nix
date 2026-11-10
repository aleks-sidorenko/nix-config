{
  flake.modules.nixos.locale =
    { config, lib, ... }:
    let
      inherit (config.constants.locale) locales layouts timeZone;
      systemLocale = lib.head locales;
      extraLocales = lib.tail locales;
      nativeLocale = if extraLocales == [ ] then systemLocale else lib.head extraLocales;
    in
    {
      i18n = {
        defaultLocale = lib.mkDefault systemLocale;
        supportedLocales = lib.mkDefault (map (locale: "${locale}/UTF-8") locales);
        extraLocaleSettings = {
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

      time.timeZone = lib.mkDefault timeZone;

      services.xserver.xkb = {
        layout = lib.concatStringsSep "," layouts;
        options = "grp:win_space_toggle";
        variant = "";
      };

      console.keyMap = lib.head layouts;
    };
}
