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
  flake.modules.nixos.radarr =
    { config, ... }:
    let
      media = config.nix-config.media;
      dataDir = "/var/lib/radarr";
    in
    {
      imports = [
        (topConfig.factory.arr {
          name = "radarr";
          title = "Radarr";
          userDescription = "Radarr movie management user";
        })
      ];

      services.radarr = {
        user = "radarr";
        inherit (media) group;
        inherit dataDir;
        settings.server.port = 7878;
      };

      # Ensure directories exist and have correct permissions
      systemd.tmpfiles.rules = [
        "d ${dataDir} 0755 radarr ${media.group} -"
        # Create root directories
        "d ${media.mediaRoot} 0775 radarr ${media.group} -"
        # Create category-specific directories
        "d ${media.mediaDir media.categories.movies} 0775 radarr ${media.group} -"
      ];
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
