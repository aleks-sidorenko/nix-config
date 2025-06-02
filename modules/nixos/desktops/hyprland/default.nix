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

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      WLR_NO_HARDWARE_CURSORS = "1";
      GBM_BACKEND = "nvidia-drm";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      LIBVA_DRIVER_NAME = "nvidia";
      NVD_BACKEND = "direct";
    };

    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      withUWSM = false;
    };

  };
}
