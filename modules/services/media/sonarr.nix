{ config, lib, ... }:
let
  topConfig = config;
  # radarr imported last, so its rules would come first by import order.
  both =
    (config.builders.testNixos {
      imports = with config.flake.modules.nixos; [
        sonarr
        radarr
        sops
        nginx
      ];
    }).config;
in
{
  flake.modules.nixos.sonarr = {
    imports = [
      (topConfig.factory.arr {
        name = "sonarr";
        title = "Sonarr";
        userDescription = "Sonarr TV show management user";
        category = "series";
        ownsMediaRoot = true;
      })
    ];
  };

  # The live /data/media is sonarr's; tmpfiles re-owns it to whoever's rule
  # comes first.
  evalTests.sonarr-owns-media-root = {
    expr = lib.findFirst (lib.hasPrefix "d /data/media ") null both.systemd.tmpfiles.rules;
    expected = "d /data/media 0775 sonarr media -";
  };
}
