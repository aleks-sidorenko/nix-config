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

in
{
  config = mkIf cfg.enable {
    dconf.settings = {
      "org/gnome/desktop/applications/terminal" = {
        exec = "${pkgs.${cfg.terminal}}/bin/${cfg.terminal}";
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
        binding = "<Super>Return";
        command = cfg.terminal;
        name = "Open Terminal";
      };

      "org/gnome/desktop/wm/keybindings" = {
        close = [ "<Super>q" ];
      };

      "com/github/stunkymonkey/nautilus-open-any-terminal" = {
        terminal = cfg.terminal;
      };

      "org/gnome/shell/extensions/search-light" = {
        shortcut-search = [ "<Super>b" ];
      };
    };
  };
}
