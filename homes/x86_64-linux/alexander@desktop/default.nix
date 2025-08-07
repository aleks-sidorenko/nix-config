{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
{

  # TODO - replace with ${namespace} once this is fixed https://github.com/snowfallorg/lib/issues/142
  nix-config = {
    roles = {
      desktop = enabled;
    };

    user = {
      enable = true;
      name = "alexander";
    };

    security.sops.enable = mkForce false;

    desktops.monitors = {
      enable = true;
      devices = [
        {
          name = "DVI-D-1";
          model = "Samsung SyncMaster PX2370";
          width = 1920;
          height = 1080;
          primary = true;
          workspace = "1";
        }
        {
          name = "HDMI-1";
          model = "Dell U2414H";
          width = 1920;
          height = 1080;
          workspace = "1";
          position = "auto-right";
        }

      ];

    };

  };

  home.stateVersion = "25.05";
}
