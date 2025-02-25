{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib; let
  cfg = config.${namespace}.desktops.addons.pyprland;
in {
  options.${namespace}.desktops.addons.pyprland = {
    enable = mkEnableOption "Enable pyprland plugins for hyprland";
  };

  config = mkIf cfg.enable {
    xdg.configFile."hypr/pyprland.toml".source = ./pyprland.toml;

    home = {
      packages = with pkgs; [pyprland];
    };
  };
}
