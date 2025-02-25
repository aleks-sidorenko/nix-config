{
  options,
  config,
  lib,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.system.locale;
  locale = "en_US.UTF-8";
  layout = "us";
  timeZone = "Europe/Kyiv";
in {
  options.system.locale = with types; {
    enable = mkBoolOpt false "Whether or not to manage locale settings.";
  };

  config = mkIf cfg.enable {
    i18n = {
      
      defaultLocale = lib.mkDefault ${locale};

      extraLocaleSettings = {
        LC_ADDRESS = ${locale};
        LC_IDENTIFICATION = ${locale};
        LC_MEASUREMENT = ${locale};
        LC_MONETARY = ${locale};
        LC_NAME = ${locale};
        LC_NUMERIC = ${locale};
        LC_PAPER = ${locale};
        LC_TELEPHONE = ${locale};
        LC_TIME = ${locale};
      };
    };
    time.timeZone = ${timeZone};

    # Configure keymap in X11
    services.xserver = {
      xkb =  {
        layout = ${layout};
        variant = "";
      };
    };

    # Configure console keymap
    console.keyMap = ${layout};
  };
}
