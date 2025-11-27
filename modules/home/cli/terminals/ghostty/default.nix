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

    # Enable Catppuccin theme for Ghostty
    catppuccin.ghostty.enable = true;

    programs.ghostty = {
      enable = true;
      enableFishIntegration = true;

      settings = {
      
        command = shell;
        gtk-titlebar = false;
        gtk-tabs-location = "hidden";
        gtk-single-instance = true;
        window-padding-x = 6;
        window-padding-y = 6;
        window-save-state = "always";
        copy-on-select = "clipboard";
        cursor-style = "block";
        confirm-close-surface = false;
        # https://sterba.dev/posts/replacing-tmux/
        keybind = [
          "clear"

          # Split management
          "ctrl+shift+h=goto_split:left"
          "ctrl+shift+j=goto_split:bottom"
          "ctrl+shift+k=goto_split:top"
          "ctrl+shift+l=goto_split:right"
          
          "ctrl+shift+-=new_split:down"          
          "ctrl+shift+|=new_split:right"          
          "ctrl+shift+f=toggle_split_zoom"
          
          # Tab management
          "ctrl+shift+]=next_tab"
          "ctrl+shift+[=previous_tab"
          "ctrl+shift+n=new_tab"
          "ctrl+shift+q=close_tab"
          
          # Reload config
          "super+r=reload_config"

          # Claude Code
          "shift+enter=text:\u001b[13;2u"
        ];
      };
    };
  };
}
