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
          name = "DVI-I-1";
          width = 1920;
          height = 1080;
          workspace = "1";
          primary = true;
        }
        {
          name = "HDMI-A-1";
          width = 1920;
          height = 1080;
          position = "auto-right";
          workspace = "2";
        }
      ];

    };

  };

  home.stateVersion = "25.05";
}
