let
  webPort = 8096;
  dataDir = "/var/lib/jellyfin";
in
{
  den.aspects.services.jellyfin = {
    persist.directories = [ dataDir ];
    installChecks = [ ''machine.wait_for_unit("jellyfin.service")'' ];

    vhosts = [
      {
        name = "jellyfin";
        port = webPort;
      }
    ];

    nixos =
      { host, ... }:
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
          cacheDir = "${dataDir}/cache";
          logDir = "${dataDir}/log";
        };

        systemd.tmpfiles.rules = [
          "d ${dataDir} 0755 jellyfin ${media.group} -"
          "d ${dataDir}/config 0755 jellyfin ${media.group} -"
          "d ${dataDir}/cache 0755 jellyfin ${media.group} -"
          "d ${dataDir}/log 0755 jellyfin ${media.group} -"
        ];
      };
  };
}
