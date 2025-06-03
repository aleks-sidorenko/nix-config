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
  terminalPkg = config.${namespace}.cli.terminals.terminal;
  terminal = terminalPkg.pname;
in
{
  config = mkIf cfg.enable {
    dconf.settings = {
      "org/gnome/desktop/applications/terminal" = {
        exec = "${terminalPkg}/bin/${terminal}";
      };

      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
        binding = "<Super>Return";
        command = terminal;
        name = "Open Terminal";
      };

      "org/gnome/desktop/wm/keybindings" = {
        close = [ "<Super>q" ];
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
