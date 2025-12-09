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

        keybind = [
          "clear"

          # Tab Management (Ctrl+Shift for terminal operations)
          "ctrl+shift+t=new_tab"
          "ctrl+shift+w=close_tab:this"
          "ctrl+shift+arrow_left=previous_tab"
          "ctrl+shift+arrow_right=next_tab"
          "ctrl+shift+[=previous_tab"
          "ctrl+shift+]=next_tab"

          # Quick Tab Access (Alt+1-9)
          "alt+1=goto_tab:1"
          "alt+2=goto_tab:2"
          "alt+3=goto_tab:3"
          "alt+4=goto_tab:4"
          "alt+5=goto_tab:5"
          "alt+6=goto_tab:6"
          "alt+7=goto_tab:7"
          "alt+8=goto_tab:8"
          "alt+9=last_tab"

          # Split Navigation (Alt+Shift to avoid GNOME conflicts)
          # vim style
          "alt+shift+h=goto_split:left"
          "alt+shift+j=goto_split:down"
          "alt+shift+k=goto_split:up"
          "alt+shift+l=goto_split:right"
          # arrows
          "alt+shift+arrow_up=goto_split:up"
          "alt+shift+arrow_down=goto_split:down"
          "alt+shift+arrow_left=goto_split:left"
          "alt+shift+arrow_right=goto_split:right"

          # Split Creation (Ctrl+Shift)
          # vim style (ctrl+shift+hjkl)
          "ctrl+shift+h=new_split:left"
          "ctrl+shift+j=new_split:down"
          "ctrl+shift+k=new_split:up"
          "ctrl+shift+l=new_split:right"
          # arrows
          "ctrl+shift+arrow_up=new_split:up"
          "ctrl+shift+arrow_down=new_split:down"
          "ctrl+shift+arrow_left=new_split:left"
          "ctrl+shift+arrow_right=new_split:right"
          # logicial
          "ctrl+shift+|=new_split:right"
          "ctrl+shift+-=new_split:down"

          "ctrl+shift+enter=toggle_split_zoom"

          # Split Resize (Alt+Shift+Ctrl)
          # vim style
          "alt+shift+ctrl+h=resize_split:left,10"
          "alt+shift+ctrl+j=resize_split:down,10"
          "alt+shift+ctrl+k=resize_split:up,10"
          "alt+shift+ctrl+l=resize_split:right,10"
          # arrows
          "alt+shift+ctrl+arrow_up=resize_split:up,10"
          "alt+shift+ctrl+arrow_down=resize_split:down,10"
          "alt+shift+ctrl+arrow_left=resize_split:left,10"
          "alt+shift+ctrl+arrow_right=resize_split:right,10"

          #

          # Copy/Paste (Standard)
          "ctrl+shift+c=copy_to_clipboard"
          "ctrl+shift+v=paste_from_clipboard"
          "ctrl+shift+a=select_all"
          "shift+insert=paste_from_selection"
          "ctrl+insert=copy_to_clipboard"

          # Font/Display (Ctrl)

          "ctrl++=increase_font_size:1"
          "ctrl+-=decrease_font_size:1"
          "ctrl+0=reset_font_size"
          "ctrl+enter=toggle_fullscreen"

          # Configuration (Ctrl+Shift)
          "ctrl+,=open_config"
          "ctrl+shift+,=reload_config"
          "ctrl+shift+p=toggle_command_palette"
          "ctrl+shift+i=inspector:toggle"

          # Window Management
          "ctrl+shift+n=new_window"
          "ctrl+shift+q=quit"
          "alt+f4=close_window"

          # Navigation
          "ctrl+shift+page_up=jump_to_prompt:-1"
          "ctrl+shift+page_down=jump_to_prompt:1"
          "shift+page_up=scroll_page_up"
          "shift+page_down=scroll_page_down"
          "shift+home=scroll_to_top"
          "shift+end=scroll_to_bottom"

          # Selection (arrows only - shift+letter conflicts with typing capitals)
          "shift+arrow_up=adjust_selection:up"
          "shift+arrow_down=adjust_selection:down"
          "shift+arrow_left=adjust_selection:left"
          "shift+arrow_right=adjust_selection:right"

          # Write to File (Prefix: Ctrl+A, then key)
          # Actions: key = paste, shift+key = open, ctrl+key = copy
          # Screen (s)
          "ctrl+a>s=write_screen_file:paste"
          "ctrl+a>shift+s=write_screen_file:open"
          "ctrl+a>ctrl+s=write_screen_file:copy"
          # Scrollback (b for buffer)
          "ctrl+a>b=write_scrollback_file:paste"
          "ctrl+a>shift+b=write_scrollback_file:open"
          "ctrl+a>ctrl+b=write_scrollback_file:copy"
          # Selection (e for excerpt)
          "ctrl+a>e=write_selection_file:paste"
          "ctrl+a>shift+e=write_selection_file:open"
          "ctrl+a>ctrl+e=write_selection_file:copy"

          # Claude Code
          "shift+enter=text:\u001b[13;2u"
        ];
      };
    };
  };
}
