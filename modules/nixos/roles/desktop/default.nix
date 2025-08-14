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
        common.enable = true;

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
        # TODO impl
        # backup.enable = true;
        # TODO impl
        # vpn.enable = true;
        # virtualisation.podman.enable = true;
      };

      disks = {
        boot = {
          hibernation.enable = true;
        };
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
