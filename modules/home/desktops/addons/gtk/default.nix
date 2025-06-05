{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.desktops.addons.gtk;
in
{
  options.${namespace}.desktops.addons.gtk = {
    enable = mkEnableOption "Enable GTK theme management.";
  };

  config = mkIf cfg.enable {

    stylix.targets.gtk.enable = true; # Enable Stylix for GTK

    gtk = {
      enable = true;
    };

    xdg.portal = {
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config = {
        common = {
          # Let Hyprland be the primary portal implementation
          default = [
            "gtk"
          ];
          # GTK should handle these specific portals
          "org.freedesktop.impl.portal.Secret" = [
            "gtk"
          ];
          "org.freedesktop.impl.portal.Settings" = [
            "gtk"
          ];
        };
      };
    };
  };
}
