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
    };

    security.sops.enable = mkForce false;

    desktops.monitors = {
      enable = true;
      devices = [
        {
          name = "DVI-D-1";
          vendor = "DEL";
          model = "DELL U2419H";
          serial = "153FD23";
          width = 1920;
          height = 1080;
          refreshRate = 60;
          primary = true;
          position = "0";
          scale = "1";
          workspace = "1";
        }
        {
          name = "HDMI-1";
          vendor = "SAM";
          model = "SyncMaster";
          serial = "H9MZ504458";
          width = 1920;
          height = 1080;
          refreshRate = 60;
          position = "1920";
          scale = "1";
          workspace = "1";
        }

      ];

    };

  };

  home.stateVersion = "25.05";
}
