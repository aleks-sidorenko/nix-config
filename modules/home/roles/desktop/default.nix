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
  cfg = config.${namespace}.roles.desktop;
in
{
  options.${namespace}.roles.desktop = {
    enable = mkEnableOption "Enable desktop suite";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      roles = {
        common = enabled;
        development = {
          enable = true;
          ai = {
            copilot = false;
            claude-code = true;
          };
          languages = {
            haskell = true;
            rust = false;
            python = true;
            go = false;
            typescript = true;
          };
        };
        media = enabled;
        mobile = enabled;
        gaming = enabled;
        social = enabled;
      };

      services = {
        kdeconnect.enable = false;
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
    # Linux-only systemd target
    systemd.user.targets.tray = mkIf pkgs.stdenv.isLinux {
      Unit = {
        Description = "Home Manager System Tray";
        Requires = [ "graphical-session-pre.target" ];
      };
    };

    # Linux/Wayland-specific session variables
    home.sessionVariables = mkIf pkgs.stdenv.isLinux {
      MOZ_ENABLE_WAYLAND = 1;
      QT_QPA_PLATFORM = "wayland;xcb";
      LIBSEAT_BACKEND = "logind";
    };

    # Linux-only packages (Wayland tools)
    home.packages = mkIf pkgs.stdenv.isLinux (
      with pkgs;
      [
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
      ]
    );
  };
}
