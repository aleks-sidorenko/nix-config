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
    enable = mkBoolOpt false "Enable or disable the gnome DE.";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      desktops.addons.nautilus.enable = true;
    };

    services = {
      xserver = {
        enable = true;
        displayManager.gdm.enable = true;
        desktopManager.gnome = {
          enable = true;
          extraGSettingsOverridePackages = with pkgs; [
            nautilus-open-any-terminal
          ];
        };
      };
    };

    services.udev.packages = with pkgs; [ gnome-settings-daemon ];
    programs.dconf.enable = true;

  };
}
