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
        open-terminal = [ ];
      };

      "org/gnome/shell/keybindings/toggle-application-view" = {
        "@as" = [ ];
      };

      "org/gnome/settings-daemon/plugins/media-keys" = {
        www = [ "<Super>w" ];
        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        ];
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
        name = "Open Terminal (Super+t)";
        command = terminal;
        binding = "<Super>t";
      };

      "org/gnome/desktop/wm/keybindings" = {
        activate-window-menu = [ "<Alt>space" ];
        always-on-top = [ ];
        begin-move = [ "<Alt>F7" ];
        begin-resize = [ "<Alt>F8" ];
        close = [ "<Super>q" ];
        cycle-group = [ "<Alt>F6" ];
        cycle-group-backward = [ "<Shift><Alt>F6" ];
        cycle-panels = [ "<Ctrl><Alt>Escape" ];
        cycle-panels-backward = [ "<Shift><Ctrl><Alt>Escape" ];
        cycle-windows = [ "<Alt>Escape" ];
        cycle-windows-backward = [ "<Shift><Alt>Escape" ];
        lower = [ ];
        maximize = [ "<Super>Up" ];
        maximize-horizontally = [ ];
        maximize-vertically = [ ];
        minimize = [ "<Super>h" ];
        move-to-monitor-down = [ "<Super><Shift>Down" ];
        move-to-monitor-left = [ "<Super><Shift>Left" ];
        move-to-monitor-right = [ "<Super><Shift>Right" ];
        move-to-monitor-up = [ "<Super><Shift>Up" ];
        move-to-workspace-1 = [ "<Super><Shift>Home" ];
        move-to-workspace-down = [ "<Ctrl><Shift><Alt>Down" ];
        move-to-workspace-last = [ "<Super><Shift>End" ];
        move-to-workspace-left = [
          "<Super><Shift>Page_Up"
          "<Super><Shift><Alt>Left"
          "<Ctrl><Shift><Alt>Left"
        ];
        move-to-workspace-right = [
          "<Super><Shift>Page_Down"
          "<Super><Shift><Alt>Right"
          "<Ctrl><Shift><Alt>Right"
        ];
        move-to-workspace-up = [ "<Ctrl><Shift><Alt>Up" ];
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
          "XF86Keyboard"
        ];
        switch-input-source-backward = [
          "<Shift><Super>space"
          "<Shift>XF86Keyboard"
        ];
        switch-panels = [ "<Ctrl><Alt>Tab" ];
        switch-panels-backward = [ "<Shift><Ctrl><Alt>Tab" ];
        switch-to-workspace-1 = [ "<Super>Home" ];
        switch-to-workspace-down = [ "<Ctrl><Alt>Down" ];
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
        switch-to-workspace-up = [ "<Ctrl><Alt>Up" ];
        toggle-maximized = [ "<Alt>F10" ];
        unmaximize = [
          "<Super>Down"
          "<Alt>F5"
        ];
      };

      "org/gnome/shell/extensions/search-light" = {
        shortcut-search = [ "<Super>b" ];
      };
    };
  };
}
