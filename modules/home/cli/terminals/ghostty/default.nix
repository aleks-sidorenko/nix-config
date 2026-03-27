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
  shellCfg = config.${namespace}.cli.shells.default;
  shell = lib.getExe shellCfg.package;
  prefix = "ctrl+a";
in
{
  options.${namespace}.cli.terminals.ghostty = {
    enable = mkEnableOption "Enable ghostty terminal emulator";
    default = mkBoolOpt false "Whether or not to use ghostty as the default terminal";
    package = mkPackageOpt pkgs.ghostty "Package to use for ghostty terminal";
  };

  config = mkIf cfg.enable {
    ${namespace}.cli.terminals.default = mkIf cfg.default {
      enable = true;
      name = "ghostty";
      inherit (cfg) package;
    };

    # Enable Catppuccin theme for Ghostty
    catppuccin.ghostty.enable = true;

    programs.ghostty = {
      enable = true;
      enableFishIntegration = true;
      inherit (cfg) package;
      settings = {

        command = shell;
        gtk-titlebar = false;
        gtk-tabs-location = "bottom";
        gtk-single-instance = true;
        macos-titlebar-style = "tabs";
        window-padding-x = 6;
        window-padding-y = 6;
        window-save-state = "always";
        copy-on-select = "clipboard";
        cursor-style = "block";
        confirm-close-surface = false;

        keybind = [
          "clear"

          # ── Navigate (Alt) ──────────────────────────────────────
          # Split focus — vim style
          "alt+h=goto_split:left"
          "alt+j=goto_split:down"
          "alt+k=goto_split:up"
          "alt+l=goto_split:right"
          # Split focus — arrows
          "alt+arrow_up=goto_split:up"
          "alt+arrow_down=goto_split:down"
          "alt+arrow_left=goto_split:left"
          "alt+arrow_right=goto_split:right"
          # Tab switch (1-8 direct, 9 = last)
          "alt+1=goto_tab:1"
          "alt+2=goto_tab:2"
          "alt+3=goto_tab:3"
          "alt+4=goto_tab:4"
          "alt+5=goto_tab:5"
          "alt+6=goto_tab:6"
          "alt+7=goto_tab:7"
          "alt+8=goto_tab:8"
          "alt+9=last_tab"
          # Tab cycle
          "alt+[=previous_tab"
          "alt+]=next_tab"
          # Jump to prompt
          "alt+page_up=jump_to_prompt:-1"
          "alt+page_down=jump_to_prompt:1"

          # ── Structure (Alt+Shift) ───────────────────────────────
          # Split creation — vim style
          "alt+shift+h=new_split:left"
          "alt+shift+j=new_split:down"
          "alt+shift+k=new_split:up"
          "alt+shift+l=new_split:right"
          # Split creation — arrows
          "alt+shift+arrow_up=new_split:up"
          "alt+shift+arrow_down=new_split:down"
          "alt+shift+arrow_left=new_split:left"
          "alt+shift+arrow_right=new_split:right"
          # Logical splits
          "alt+shift+|=new_split:right"
          "alt+shift+-=new_split:down"
          # Tab management
          "alt+shift+n=new_tab"
          "alt+shift+q=close_tab:this"
          # Window management
          "alt+shift+w=new_window"
          "alt+shift+x=close_window"

          # ── Modify (Alt+Ctrl) ───────────────────────────────────
          # Split resize — vim style
          "alt+ctrl+h=resize_split:left,10"
          "alt+ctrl+j=resize_split:down,10"
          "alt+ctrl+k=resize_split:up,10"
          "alt+ctrl+l=resize_split:right,10"
          # Split resize — arrows
          "alt+ctrl+arrow_up=resize_split:up,10"
          "alt+ctrl+arrow_down=resize_split:down,10"
          "alt+ctrl+arrow_left=resize_split:left,10"
          "alt+ctrl+arrow_right=resize_split:right,10"
          # Split zoom
          "alt+ctrl+enter=toggle_split_zoom"

          # ── Prefix Mode (Ctrl+A) ───────────────────────────────
          "${prefix}>h=goto_split:left"
          "${prefix}>j=goto_split:down"
          "${prefix}>k=goto_split:up"
          "${prefix}>l=goto_split:right"
          "${prefix}>[=goto_split:previous"
          "${prefix}>]=goto_split:next"
          "${prefix}>arrow_up=goto_split:up"
          "${prefix}>arrow_down=goto_split:down"
          "${prefix}>arrow_left=goto_split:left"
          "${prefix}>arrow_right=goto_split:right"
          "${prefix}>t>n=new_tab"
          "${prefix}>t>q=close_tab:this"
          "${prefix}>t>[=previous_tab"
          "${prefix}>t>]=next_tab"
          "${prefix}>w>n=new_window"
          "${prefix}>w>q=close_window"
          "${prefix}>|=new_split:right"
          "${prefix}>-=new_split:down"

          # ── Standard Bindings (non-Alt) ─────────────────────────
          # Copy/Paste
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

          # Configuration (Ctrl+;)
          "ctrl+;=open_config"
          "ctrl+shift+;=reload_config"
          # ctrl+,/. freed for Neovim move line
          "ctrl+shift+q=quit"
          "ctrl+shift+p=toggle_command_palette"
          "ctrl+shift+i=inspector:toggle"

          # Scroll/Selection
          "shift+page_up=scroll_page_up"
          "shift+page_down=scroll_page_down"
          "shift+home=scroll_to_top"
          "shift+end=scroll_to_bottom"
          "shift+arrow_up=adjust_selection:up"
          "shift+arrow_down=adjust_selection:down"
          "shift+arrow_left=adjust_selection:left"
          "shift+arrow_right=adjust_selection:right"

          # ── Write to File (Prefix) ─────────────────────────────
          # Actions: key = paste, shift+key = open, ctrl+key = copy
          # Screen (s)
          "${prefix}>s=write_screen_file:paste"
          "${prefix}>shift+s=write_screen_file:open"
          "${prefix}>ctrl+s=write_screen_file:copy"
          # Scrollback (b for buffer)
          "${prefix}>b=write_scrollback_file:paste"
          "${prefix}>shift+b=write_scrollback_file:open"
          "${prefix}>ctrl+b=write_scrollback_file:copy"
          # Selection (e for excerpt)
          "${prefix}>e=write_selection_file:paste"
          "${prefix}>shift+e=write_selection_file:open"
          "${prefix}>ctrl+e=write_selection_file:copy"

          # Claude Code
          "shift+enter=text:\u001b[13;2u"
        ];
      };
    };
  };
}
