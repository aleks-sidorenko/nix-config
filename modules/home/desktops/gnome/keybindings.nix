{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.desktops.gnome;
  terminal = lib.${namespace}.getExecPath config.${namespace}.cli.terminals.default.package;
in
{
  config = mkIf cfg.enable {
    dconf.settings = {
      "org/gnome/desktop/applications/terminal" = {
        exec = terminal;
      };

      "org/gnome/shell/keybindings" = {
        open-terminal = [ "<Ctrl><Alt>t" "<Super>t" ];        
      };

      "org/gnome/shell/keybindings/toggle-application-view" = {
        "@as" = [ ];
      };

      "org/gnome/settings-daemon/plugins/media-keys" = {
        www = [ "<Ctrl><Alt>w" "<Super>w" ];
        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
        ];
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
        name = "Open Terminal (Ctrl+Alt+t)";
        command = terminal;
        binding = "<Ctrl><Alt>t";
      };
      
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
        name = "Open Terminal (Super+t)";
        command = terminal;
        binding = "<Super>t";
      };

      "org/gnome/desktop/wm/keybindings" = {
        activate-window-menu = [ "<Alt>space" ];
        always-on-top = [ ];
        begin-move = [ ];
        begn-resize = [ ];
        close = [ "<Alt>F4" ];
        cycle-group = [ "<Alt>F6" ];
        cycle-group-backward = [ ];
        cycle-panels = [ ];
        cycle-panels-backward = [ ];
        cycle-windows = [ "<Alt>Escape" ];
        cycle-windows-backward = [ "<Shift><Alt>Escape" ];
        lower = [ ];
        maximize = [ "<Super>Up" ];
        maximize-horizontally = [ ];
        maximize-vertically = [ ];
        minimize = [ "<Super>Down" ];
        move-to-monitor-down = [ "<Super><Shift>Down" ];
        move-to-monitor-left = [ "<Super><Shift>Left" ];
        move-to-monitor-right = [ "<Super><Shift>Right" ];
        move-to-monitor-up = [ "<Super><Shift>Up" ];
        move-to-workspace-1 = [ "<Super><Shift>Home" ];
        move-to-workspace-down = [];
        move-to-workspace-last = [ "<Super><Shift>End" ];
        move-to-workspace-left = [
          "<Super><Shift>Page_Up"
          "<Super><Shift><Alt>Left"          
        ];
        move-to-workspace-right = [
          "<Super><Shift>Page_Down"
          "<Super><Shift><Alt>Right"          
        ];
        move-to-workspace-up = [ ];
        panel-run-dialog = [ "<Alt>F2" ];
        switch-applications = [
          "<Super>Tab"
          "<Alt>Tab"
        ];

        switch-applications-backward = [
          "<Shift><Super>Tab"
          "<Shift><Alt>Tab"
        ];
        switch-group = [
          "<Super>Above_Tab"
          "<Alt>Above_Tab"
        ];

        switch-group-backward = [
          "<Shift><Super>Above_Tab"
          "<Shift><Alt>Above_Tab"
        ];
        switch-input-source = [
          "<Super>space"
        ];
        switch-input-source-backward = [
          "<Shift><Super>space"
        ];
        switch-panels = [ "<Ctrl><Alt>Tab" ];
        switch-panels-backward = [ "<Shift><Ctrl><Alt>Tab" ];
        switch-to-workspace-1 = [ "<Super>Home" ];
        switch-to-workspace-down = [ ];
        switch-to-workspace-last = [ "<Super>End" ];
        switch-to-workspace-left = [
          "<Super>Page_Up"
          "<Super><Alt>Left"
          "<Ctrl><Alt>Left"
        ];
        switch-to-workspace-right = [
          "<Super>Page_Down"
          "<Super><Alt>Right"
          "<Ctrl><Alt>Right"
        ];
        switch-to-workspace-up = [ ];
        toggle-maximized = [ "<Alt>F10" ];
        unmaximize = [          
          "<Alt>F5"
        ];
      };

      "org/gnome/shell/extensions/search-light" = {
        shortcut-search = [ "<Super>b" ];
      };
    };
  };
}
