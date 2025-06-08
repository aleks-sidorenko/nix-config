{
  lib,
  pkgs,
  config,
  inputs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.styles.stylix;
in
{
  imports = with inputs; [
    stylix.homeManagerModules.stylix
    catppuccin.homeModules.catppuccin
  ];

  options.${namespace}.styles.stylix = {
    enable = lib.mkEnableOption "Enable stylix style manager.";
  };

  config = lib.mkIf cfg.enable {

    catppuccin.flavor = "mocha";

    stylix = {
      enable = true;
      autoEnable = true;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";

      image = pkgs.${namespace}.wallpapers.earth;

      iconTheme = {
        enable = true;
        package = pkgs.catppuccin-papirus-folders.override {
          flavor = "mocha";
          accent = "lavender";
        };
        dark = "Papirus-Dark";
      };

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
          package = pkgs.noto-fonts-emoji;
          name = "Noto Color Emoji";
        };
      };
    };
  };
}
