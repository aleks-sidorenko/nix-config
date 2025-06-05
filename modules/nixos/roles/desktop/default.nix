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

      desktops = {
        gnome.enable = true;
      };

      hardware = {
        audio.enable = true;
        bluetooth.enable = true;
        zsa.enable = true;
        video.nouveau.enable = true;
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
        name = "alexander";
        initialPassword = "alexander";
      };

    };
  };
}
