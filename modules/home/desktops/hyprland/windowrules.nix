{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
let
  rule = rules: attrs: attrs // { inherit rules; };
  cfg = config.${namespace}.desktops.hyprland;
in
{
  config = mkIf cfg.enable {
    wayland.windowManager.hyprland.settings = {
      windowrule = [
        "float, bitwarden"
      ];

      windowrulev2 = [
        "idleinhibit fullscreen, class:^(firefox)$"
      ];
    };
  };
}
