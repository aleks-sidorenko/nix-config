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
  terminalPkg = config.${namespace}.cli.terminals.default.package;
  terminal = terminalPkg.pname;
in
{
  config = mkIf cfg.enable {
    dconf.settings = {
      "org/gnome/desktop/applications/terminal" = {
        exec = "${lib.${namespace}.getExecPath terminalPkg}";
      };

      "org/gnome/settings-daemon/plugins/media-keys" = {
        www = ["<Ctrl><Alt>w"];
        custom-keybindings = [
          "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0"
          "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1"
        ];
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
        binding = "<Super>t";
        command = terminal;
        name = "Open terminal (Super+T)";
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
        binding = "<Ctrl><Alt>t";
        command = terminal;
        name = "Open terminal (Ctrl+Alt+T)";
      };

      "org/gnome/desktop/wm/keybindings" = {
        activate-window-menu = [ "<Alt>space" ];
        always-on-top = [ ];
        begin-move = [ "<Alt>F7" ];
        begin-resize = [ "<Alt>F8" ];
        close = [ "<Super>q" ];
        cycle-group = [ "<Alt>F6" ];
        cycle-group-backward = [ "<Shift><Alt>F6" ];
        cycle-panels = [ "<Control><Alt>Escape" ];
        cycle-panels-backward = [ "<Shift><Control><Alt>Escape" ];
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
        move-to-workspace-down = [ "<Control><Shift><Alt>Down" ];
        move-to-workspace-last = [ "<Super><Shift>End" ];
        move-to-workspace-left = [
          "<Super><Shift>Page_Up"
          "<Super><Shift><Alt>Left"
          "<Control><Shift><Alt>Left"
        ];
        move-to-workspace-right = [
          "<Super><Shift>Page_Down"
          "<Super><Shift><Alt>Right"
          "<Control><Shift><Alt>Right"
        ];
        move-to-workspace-up = [ "<Control><Shift><Alt>Up" ];
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
        switch-panels = [ "<Control><Alt>Tab" ];
        switch-panels-backward = [ "<Shift><Control><Alt>Tab" ];
        switch-to-workspace-1 = [ "<Super>Home" ];
        switch-to-workspace-down = [ "<Control><Alt>Down" ];
        switch-to-workspace-last = [ "<Super>End" ];
        switch-to-workspace-left = [
          "<Super>Page_Up"
          "<Super><Alt>Left"
          "<Control><Alt>Left"
        ];
        switch-to-workspace-right = [
          "<Super>Page_Down"
          "<Super><Alt>Right"
          "<Control><Alt>Right"
        ];
        switch-to-workspace-up = [ "<Control><Alt>Up" ];
        toggle-maximized = [ "<Alt>F10" ];
        unmaximize = [
          "<Super>Down"
          "<Alt>F5"
        ];
      };

      "com/github/stunkymonkey/nautilus-open-any-terminal" = {
        terminal = terminal;
      };

      "org/gnome/shell/extensions/search-light" = {
        shortcut-search = [ "<Super>b" ];
      };
    };
  };
}
