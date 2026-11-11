{ config, lib, ... }:
let
  topConfig = config;
  c =
    (config.builders.testNixos {
      imports = with config.flake.modules.nixos; [
        radarr
        sonarr
        prowlarr
        sops
        nginx
      ];
    }).config;
  has = rules: builtins.all (r: builtins.elem r c.systemd.tmpfiles.rules) rules;
in
{
  flake.modules.nixos.radarr = {
    imports = [
      (topConfig.factory.arr {
        name = "radarr";
        title = "Radarr";
        userDescription = "Radarr movie management user";
        category = "movies";
      })
    ];

    services.radarr.settings.server.port = 7878;
  };

  evalTests = {
    radarr-tmpfiles = {
      expr = has [
        "d /var/lib/radarr 0755 radarr media -"
        "d /data/media 0775 radarr media -"
        "d /data/media/Movies 0775 radarr media -"
      ];
      expected = true;
    };
    sonarr-tmpfiles = {
      expr = has [
        "d /var/lib/sonarr 0755 sonarr media -"
        "d /data/media 0775 sonarr media -"
        "d /data/media/Series 0775 sonarr media -"
      ];
      expected = true;
    };
    prowlarr-private-dir = {
      expr = lib.hasInfix "/var/lib/private/prowlarr/config.xml" c.systemd.services.prowlarr.preStart;
      expected = true;
    };
    arr-ports = {
      expr = map (n: c.services.${n}.settings.server.port) [
        "radarr"
        "sonarr"
        "prowlarr"
      ];
      expected = [
        7878
        8989
        9696
      ];
    };
  };
}
