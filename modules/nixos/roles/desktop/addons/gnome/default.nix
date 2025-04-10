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
  cfg = config.${namespace}.roles.desktop.addons.gnome;
in
{
  options.${namespace}.roles.desktop.addons.gnome = with types; {
    enable = mkBoolOpt false "Enable or disable the gnome DE.";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      roles.desktop.addons.nautilus.enable = true;
    };

    services = {
      xserver = {
        enable = true;
        displayManager.gdm.enable = true;
        desktopManager.gnome = {
          enable = true;
          extraGSettingsOverridePackages = [
            pkgs.nautilus-open-any-terminal
          ];
        };
      };
    };

    services.udev.packages = with pkgs; [ gnome.gnome-settings-daemon ];
    programs.dconf.enable = true;
  };
}
