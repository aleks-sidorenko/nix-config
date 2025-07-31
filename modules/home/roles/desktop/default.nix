{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.roles.desktop;
in
{
  options.${namespace}.roles.desktop = {
    enable = mkEnableOption "Enable desktop suite";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      roles = {
        common.enable = true;
        development.enable = true;
        media.enable = true;
        mobile.enable = true;
      };

      services = {
        kdeconnect.enable = false;
      };

      desktops = {
        gnome = {
          enable = true;
        };
      };

      browsers = {
        chrome = {
          enable = true;
          default = true;
        };
        firefox = {
          enable = true;
          default = false;
        };
      };

    };

    accounts = {
      contact.basePath = ".contacts";
      calendar.basePath = ".calendars";
    };

    # Fixes tray icons: https://github.com/nix-community/home-manager/issues/2064#issuecomment-887300055
    systemd.user.targets.tray = {
      Unit = {
        Description = "Home Manager System Tray";
        Requires = [ "graphical-session-pre.target" ];
      };
    };

    home.sessionVariables = {
      MOZ_ENABLE_WAYLAND = 1;
      QT_QPA_PLATFORM = "wayland;xcb";
      LIBSEAT_BACKEND = "logind";
    };

    # TODO: move this to somewhere
    home.packages = with pkgs; [

      brightnessctl # for brightness control
      xdg-utils # for xdg-open
      wl-clipboard # for clipboard
      clipse # for clipboard
      pamixer # for volume control
      playerctl # for media control

      grimblast # for screenshots
      slurp # for screenshots
      sway-contrib.grimshot # for screenshots
      satty # for brightness control
    ];
  };
}
