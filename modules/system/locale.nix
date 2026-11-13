{ lib, ... }:
let
  inherit (lib) types;
in
{
  den.schema.conf.options = {
    timeZone = lib.mkOption {
      type = types.str;
      default = "Europe/Kyiv";
      description = "Time zone (IANA name).";
    };
    locales = lib.mkOption {
      type = types.listOf types.str;
      default = [
        "en_US.UTF-8"
        "uk_UA.UTF-8"
        "ru_RU.UTF-8"
      ];
      description = "Supported locales. The first is the system locale, the second the native one for LC_* settings.";
    };
    layouts = lib.mkOption {
      type = types.listOf types.str;
      default = [
        "us"
        "ua"
        "ru"
      ];
      description = "Keyboard layouts. The first is the default.";
    };
  };

  den.aspects.system.locale = {
    os =
      { host, ... }:
      {
        time.timeZone = host.timeZone;
      };

    nixos =
      { host, ... }:
      let
        systemLocale = lib.head host.locales;
        nativeLocale = lib.head (lib.tail host.locales ++ [ systemLocale ]);
      in
      {
        i18n = {
          defaultLocale = systemLocale;
          supportedLocales = map (locale: "${locale}/UTF-8") host.locales;
          extraLocaleSettings = {
            LC_CTYPE = systemLocale;
            LC_IDENTIFICATION = systemLocale;
            LC_ADDRESS = nativeLocale;
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

        services.xserver.xkb = {
          layout = lib.concatStringsSep "," host.layouts;
          options = "grp:win_space_toggle";
        };
        console.keyMap = lib.head host.layouts;
      };
  };
}
