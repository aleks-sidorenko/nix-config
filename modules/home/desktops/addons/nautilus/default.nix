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
  cfg = config.${namespace}.desktops.addons.nautilus;
  terminal = config.${namespace}.cli.terminals.default.name;
in
{
  options.${namespace}.desktops.addons.nautilus = with types; {
    enable = mkBoolOpt false "Whether to enable the GNOME file manager.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      nautilus
      nautilus-open-any-terminal
      nautilus-python
      ffmpegthumbnailer # thumbnails
      gst_all_1.gst-libav # thumbnails
    ];

    dconf.settings = {
      "org/gnome/desktop/privacy" = {
        remember-recent-files = false;
      };
      "com/github/stunkymonkey/nautilus-open-any-terminal" = {
        terminal = terminal;
        new-tab = true;
      };
    };

  };
}
