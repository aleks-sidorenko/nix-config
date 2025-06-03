{
  config,
  lib,
  namespace,
  ...
}:
with lib;
let
  cfg = config.${namespace}.desktops.gnome.addons.gnome;
in
{
  options.${namespace}.desktops.gnome.addons.gnome = {
    enable = mkEnableOption "Enable the GNOME desktop environment addons and extras.";
  };

  config = mkIf cfg.enable {
    xdg = {
      mime.enable = true;
      systemDirs.data = [
        "${config.home.homeDirectory}/.nix-profile/share/applications"
        "${config.home.homeDirectory}/state/nix/profile/share/applications"
      ];
    };
    targets.genericLinux.enable = true;

    home.packages = with pkgs; [

      pavucontrol
      pwvucontrol
      gnome-disk-utility
      gnome-calulator
      nautilus
      nautilus-python # enable plugins
      keymapp

    ];
  };
}
