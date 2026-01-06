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
  cfg = config.${namespace}.desktops.gnome;
in
{
  options.${namespace}.desktops.gnome = with types; {
    enable = mkBoolOpt false "Enable the GNOME desktop environment and its addons.";
  };

  config = mkIf cfg.enable {

    services = {
      gvfs.enable = true; # GNOME Virtual File System
      udisks2.enable = true; # Disk management service
      udev.packages = with pkgs; [ gnome-settings-daemon ];
      desktopManager.gnome = {
        enable = true;
        extraGSettingsOverridePackages = with pkgs; [
          nautilus-open-any-terminal
        ];
      };
      xserver = {
        enable = true;
        displayManager.gdm = {
          enable = true;
          wayland = true;
        };        
      };
    };

  };
}
