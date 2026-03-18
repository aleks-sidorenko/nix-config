{
  config,
  lib,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.desktops.hyprland;
in
{
  config = mkIf cfg.enable {
    wayland.windowManager.hyprland.settings = {

      windowrule = [
        # "float, bitwarden"
      ];

      windowrulev2 = [
        "idleinhibit fullscreen, class:^(firefox)$"
      ];

    };
  };
}
