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
        font-family = "MonoLisa Nerd Font";
        command = "fish";
        gtk-titlebar = false;
        font-size = 14;
        window-padding-x = 6;
        window-padding-y = 6;
        copy-on-select = "clipboard";
        cursor-style = "block";
        confirm-close-surface = false;
      };
    };
  };
}
