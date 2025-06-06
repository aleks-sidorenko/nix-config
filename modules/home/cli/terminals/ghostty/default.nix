{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli.terminals.ghostty;
  shell = config.${namespace}.cli.shells.default.name;
in
{
  options.${namespace}.cli.terminals.ghostty = {
    enable = mkEnableOption "Enable ghostty terminal emulator.";
    default = mkBoolOpt false "Whether or not to use ghostty as the default terminal.";
  };

  config = mkIf cfg.enable {
    ${namespace}.cli.terminals.default = mkIf cfg.default {
      enable = true;
      name = "ghostty";
      package = pkgs.ghostty;
    };

    programs.ghostty = {
      enable = true;
      enableFishIntegration = true;

      settings = {
        theme = "catppuccin-mocha";
        font-family = "${config.stylix.fonts.monospace.name}";
        font-size = 14;
        command = shell;
        gtk-titlebar = false;
        gtk-tabs-location = "hidden";
        gtk-single-instance = true;        
        window-padding-x = 6;
        window-padding-y = 6;
        copy-on-select = "clipboard";
        cursor-style = "block";
        confirm-close-surface = false;
        keybind = [
          "ctrl+shift+plus=increase_font_size:1"
        ];
      };
    };
  };
}
