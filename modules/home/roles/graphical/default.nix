{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};

let
  cfg = config.${namespace}.roles.graphical;
in
{
  options.${namespace}.roles.graphical = {
    enable = mkEnableOption "Enable the graphical environment suite";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isLinux;
        message = "The graphical role is only supported on NixOS (Linux) systems";
      }
    ];

    ${namespace} = {
      roles = {
        common = enabled;
        media = enabled;
      };

      services = {
        teamviewer = enabled;
        kdeconnect = disabled;
      };

      desktops = {
        gnome = enabled;
      };

      browsers = {
        chrome = {
          enable = true;
          default = false;
        };
        firefox = {
          enable = true;
          default = true;
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

    # Wayland-specific session variables
    home.sessionVariables = {
      MOZ_ENABLE_WAYLAND = 1;
      QT_QPA_PLATFORM = "wayland;xcb";
      LIBSEAT_BACKEND = "logind";
    };

    # Wayland tools
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
