{ config, ... }:
let
  topConfig = config;
in
{
  flake.modules.nixos.sonarr =
    { config, ... }:
    let
      media = config.nix-config.media;
      dataDir = "/var/lib/sonarr";
    in
    {
      imports = [
        (topConfig.factory.arr {
          name = "sonarr";
          title = "Sonarr";
          userDescription = "Sonarr TV show management user";
        })
      ];

      services.sonarr = {
        user = "sonarr";
        inherit (media) group;
        inherit dataDir;
      };

      # Ensure directories exist and have correct permissions
      systemd.tmpfiles.rules = [
        "d ${dataDir} 0755 sonarr ${media.group} -"
        # Create root directories
        "d ${media.mediaRoot} 0775 sonarr ${media.group} -"
        # Create category-specific directories
        "d ${media.mediaDir media.categories.series} 0775 sonarr ${media.group} -"
      ];
    };
}
