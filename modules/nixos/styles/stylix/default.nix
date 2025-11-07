{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.styles.stylix;
in
{
  options.${namespace}.styles.stylix = {
    enable = lib.mkEnableOption "Enable stylix theme management on the system level.";
  };

  config = lib.mkIf cfg.enable {

    stylix = {
      enable = true;
      autoEnable = true;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
      homeManagerIntegration.autoImport = false;
      homeManagerIntegration.followSystem = false;

      image = pkgs.${namespace}.wallpapers.earth;

      cursor = {
        name = "Bibata-Modern-Classic";
        package = pkgs.bibata-cursors;
        size = 24;
      };

      fonts = {
        sizes = {
          terminal = 14;
          applications = 12;
          popups = 12;
        };

        monospace = {
          name = "FiraMono Nerd Font";
          package = pkgs.nerd-fonts.fira-mono;
        };

        sansSerif = {
          name = "Fira Sans";
          package = pkgs.fira;
        };

        serif = {
          name = "Source Serif";
          package = pkgs.source-serif;
        };

        emoji = {
          package = pkgs.noto-fonts-color-emoji;
          name = "Noto Color Emoji";
        };
      };
    };
  };
}
