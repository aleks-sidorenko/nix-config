{
  options,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.roles.desktop.addons.hyprland;
in {
  options.${namespace}.roles.desktop.addons.hyprland = with types; {
    enable = mkBoolOpt false "Enable or disable the hyprland window manager.";
  };

  config = mkIf cfg.enable {
    environment.sessionVariables.NIXOS_OZONE_WL = "1";
    programs.hyprland.enable = true;
    roles.desktop.addons.greetd.enable = true;
    roles.desktop.addons.xdg-portal.enable = true;
  };
}
