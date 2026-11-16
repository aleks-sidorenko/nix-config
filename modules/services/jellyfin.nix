let
  webPort = 8096;
  dataDir = "/var/lib/jellyfin";
  cacheDir = "${dataDir}/cache";
in
{
  den.aspects.services.jellyfin = {
    persist.directories = [ dataDir ];
    # Regenerable, and most of a backup by size.
    backup.exclude = [ cacheDir ];
    installChecks = [ ''machine.wait_for_unit("jellyfin.service")'' ];

    vhosts = [
      {
        name = "jellyfin";
        port = webPort;
      }
    ];

    nixos =
      { config, host, ... }:
      let
        media = import ./_media.nix host.mediaRoot;
      in
      {
        users.groups.${media.group} = { };

        services.jellyfin = {
          enable = true;
          inherit (media) group;
          # nginx is the ingress; opening the port here would let clients bypass it.
          openFirewall = false;
          inherit dataDir;
          configDir = "${dataDir}/config";
          inherit cacheDir;
          logDir = "${dataDir}/log";
        };

        environment.systemPackages = [ config.services.jellyfin.package ];

        systemd.tmpfiles.rules = [
          "d ${dataDir} 0755 jellyfin ${media.group} -"
          "d ${dataDir}/config 0755 jellyfin ${media.group} -"
          "d ${cacheDir} 0755 jellyfin ${media.group} -"
          "d ${dataDir}/log 0755 jellyfin ${media.group} -"
        ];
      };
  };
}
