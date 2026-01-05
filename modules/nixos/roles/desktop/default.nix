{
  lib,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.desktop;
in
{
  options.${namespace}.roles.desktop = {
    enable = mkEnableOption "Enable desktop configuration";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      roles = {
        common = enabled;
        gaming = enabled;
        backup = enabled;
      };

      cli = {

        tools = {
          nh.enable = true;
          nix-ld.enable = true;
        };
      };

      styles.stylix.enable = true;

      desktops = {
        gnome.enable = true;
      };

      services = {
        virtualisation.kvm = enabled;
        virtualisation.virtualbox = enabled;
      };

      disks = {
        hibernation.enable = true;
      };

      user = {
        # we need this for desktop
        extraGroups = [
          "audio"
          "sound"
          "video"
        ];
      };
    };
  };
}
