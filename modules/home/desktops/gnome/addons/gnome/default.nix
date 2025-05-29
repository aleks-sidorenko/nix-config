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
    enable = mkEnableOption "enable gnome extras to work with home-manager";
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
  };
}
