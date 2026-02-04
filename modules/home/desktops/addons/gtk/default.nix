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
    enable = mkEnableOption "Enable GTK theme management";
  };

  config = mkIf cfg.enable {

    stylix.targets.gtk.enable = true; # Enable Stylix for GTK

    gtk = {
      enable = true;
    };

    xdg.portal = {
      extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
      configPackages = with pkgs; [ xdg-desktop-portal-gtk ];
    };
  };
}
