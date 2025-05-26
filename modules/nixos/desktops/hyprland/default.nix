{
  options,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktops.hyprland;
in
{
  options.${namespace}.desktops.hyprland = with types; {
    enable = mkBoolOpt false "Enable or disable the hyprland window manager.";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      desktops.addons.greetd.enable = true;
      desktops.addons.xdg-portal.enable = true;
    };

    environment.sessionVariables.NIXOS_OZONE_WL = "1";
    programs.hyprland.enable = true;

  };
}
