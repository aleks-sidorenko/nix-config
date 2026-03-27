{
  config,
  lib,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.desktops.gnome;
  terminal = lib.getExe config.${namespace}.cli.terminals.default.package;
in
{
  config = mkIf cfg.enable {
    dconf.settings = {
      # Terminal
      "org/gnome/desktop/applications/terminal" = {
        exec = terminal;
      };

      # Shell keybindings
      "org/gnome/shell/keybindings" = {
        toggle-application-view = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        toggle-message-tray = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
      };

      # Media keys, screenshots, lock, power menu
      "org/gnome/settings-daemon/plugins/media-keys" = {
        www = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        screensaver = [ "<Super>BackSpace" ];
        logout = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        screenshot = [ "Print" ];
        window-screenshot = [ "<Shift>Print" ];
        area-screenshot = [ "<Ctrl>Print" ];
        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
        ];
      };

      # Power menu via custom keybinding
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
        name = "Power Menu";
        command = "gnome-session-quit --power-off";
        binding = "<Ctrl><Super>BackSpace";
      };

      # Terminal via custom keybindings
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
        name = "Terminal (Super+T)";
        command = terminal;
        binding = "<Super>t";
      };

      # Search light — new binding
      "org/gnome/shell/extensions/search-light" = {
        shortcut-search = [ "<Super>d" ];
      };

      # Window management
      "org/gnome/desktop/wm/keybindings" = {
        activate-window-menu = [ "<Alt>space" ];
        close = [
          "<Super>q"
          "<Alt>F4"
        ];
        toggle-fullscreen = [ "<Super>f" ];
        always-on-top = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        begin-move = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        begin-resize = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        cycle-group = [ "<Alt>F6" ];
        cycle-group-backward = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        cycle-panels = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        cycle-panels-backward = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        cycle-windows = [ "<Alt>Escape" ];
        cycle-windows-backward = [ "<Shift><Alt>Escape" ];
        lower = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        maximize = [ "<Super>Up" ];
        maximize-horizontally = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        maximize-vertically = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        minimize = [ "<Super>Down" ];
        move-to-monitor-down = [
          "<Super><Ctrl>j"
          "<Super><Shift>Down"
        ];
        move-to-monitor-left = [
          "<Super><Ctrl>h"
          "<Super><Shift>Left"
        ];
        move-to-monitor-right = [
          "<Super><Ctrl>l"
          "<Super><Shift>Right"
        ];
        move-to-monitor-up = [
          "<Super><Ctrl>k"
          "<Super><Shift>Up"
        ];
        move-to-workspace-1 = [
          "<Super><Shift>1"
          "<Super><Shift>Home"
        ];
        move-to-workspace-2 = [ "<Super><Shift>2" ];
        move-to-workspace-3 = [ "<Super><Shift>3" ];
        move-to-workspace-4 = [ "<Super><Shift>4" ];
        move-to-workspace-5 = [ "<Super><Shift>5" ];
        move-to-workspace-6 = [ "<Super><Shift>6" ];
        move-to-workspace-7 = [ "<Super><Shift>7" ];
        move-to-workspace-8 = [ "<Super><Shift>8" ];
        move-to-workspace-9 = [ "<Super><Shift>9" ];
        move-to-workspace-10 = [ "<Super><Shift>0" ];
        move-to-workspace-down = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        move-to-workspace-last = [ "<Super><Shift>End" ];
        move-to-workspace-left = [ "<Super><Shift><Alt>Left" ];
        move-to-workspace-right = [ "<Super><Shift><Alt>Right" ];
        move-to-workspace-up = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
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
        switch-input-source = [ "<Super>space" ];
        switch-input-source-backward = [ "<Shift><Super>space" ];
        switch-panels = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        switch-panels-backward = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        switch-to-workspace-1 = [
          "<Super>1"
          "<Super>Home"
        ];
        switch-to-workspace-2 = [ "<Super>2" ];
        switch-to-workspace-3 = [ "<Super>3" ];
        switch-to-workspace-4 = [ "<Super>4" ];
        switch-to-workspace-5 = [ "<Super>5" ];
        switch-to-workspace-6 = [ "<Super>6" ];
        switch-to-workspace-7 = [ "<Super>7" ];
        switch-to-workspace-8 = [ "<Super>8" ];
        switch-to-workspace-9 = [ "<Super>9" ];
        switch-to-workspace-10 = [
          "<Super>0"
          "<Super>End"
        ];
        switch-to-workspace-down = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        switch-to-workspace-left = [ "<Super><Alt>Left" ];
        switch-to-workspace-right = [ "<Super><Alt>Right" ];
        switch-to-workspace-up = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        toggle-maximized = [ "<Super>m" ];
        unmaximize = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
      };

      # Static workspaces
      "org/gnome/mutter" = {
        dynamic-workspaces = false;
      };

      "org/gnome/desktop/wm/preferences" = {
        num-workspaces = 10;
      };

      # Forge tiling keybindings
      "org/gnome/shell/extensions/forge/keybindings" = {
        window-focus-left = [ "<Super>h" ];
        window-focus-right = [ "<Super>l" ];
        window-focus-up = [ "<Super>k" ];
        window-focus-down = [ "<Super>j" ];
        window-move-left = [ "<Super><Shift>h" ];
        window-move-right = [ "<Super><Shift>l" ];
        window-move-up = [ "<Super><Shift>k" ];
        window-move-down = [ "<Super><Shift>j" ];
        window-resize-left-increase = [ "<Super><Alt>h" ];
        window-resize-right-increase = [ "<Super><Alt>l" ];
        window-resize-top-increase = [ "<Super><Alt>k" ];
        window-resize-bottom-increase = [ "<Super><Alt>j" ];
      };
    };
  };
}
