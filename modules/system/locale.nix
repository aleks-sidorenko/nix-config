{
  flake.modules.nixos.locale =
    { config, lib, ... }:
    let
      inherit (config.nix-config.locale) locales layouts timeZone;
      systemLocale = lib.head locales;
      extraLocales = lib.tail locales;
      nativeLocale = if extraLocales == [ ] then systemLocale else lib.head extraLocales;
    in
    {
      # The owner's locale is the default; a type for machines nobody sits at
      # can set its own.
      options.nix-config.locale = {
        locales = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = config.constants.locale.locales;
          description = "Supported locales. The first is the system locale, the second the native one for LC_* settings.";
        };
        layouts = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = config.constants.locale.layouts;
          description = "Keyboard layouts. The first is the default.";
        };
        timeZone = lib.mkOption {
          type = lib.types.str;
          default = config.constants.locale.timeZone;
          description = "Time zone (IANA name).";
        };
      };

      config = {
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
    };
}
