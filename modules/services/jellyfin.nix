let
  webPort = 8096;
  stateDir = "/var/lib/jellyfin";
  cacheDir = "${stateDir}/cache";
in
{
  den.aspects.services.jellyfin = {
    persist.directories = [ stateDir ];
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
          # The live database is under data/; pointing this at the state
          # directory would start jellyfin on an empty library.
          dataDir = "${stateDir}/data";
          configDir = "${stateDir}/config";
          inherit cacheDir;
          logDir = "${stateDir}/log";
        };

        environment.systemPackages = [ config.services.jellyfin.package ];

        systemd.tmpfiles.rules = [
          "d ${stateDir} 0755 jellyfin ${media.group} -"
          "d ${stateDir}/config 0755 jellyfin ${media.group} -"
          "d ${cacheDir} 0755 jellyfin ${media.group} -"
          "d ${stateDir}/log 0755 jellyfin ${media.group} -"
        ];
      };
  };
}
