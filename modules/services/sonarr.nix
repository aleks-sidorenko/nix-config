let
  webPort = 8989;
  dataDir = "/var/lib/sonarr";
in
{
  den.aspects.services.sonarr = {
    persist.directories = [ dataDir ];
    installChecks = [ ''machine.wait_for_unit("sonarr.service")'' ];

    vhosts = [
      {
        name = "sonarr";
        port = webPort;
        # config.xml sets External authentication: the app authenticates nobody
        # and serves its API key to whoever asks.
        requiresProxyAuth = true;
      }
    ];

    nixos =
      {
        config,
        host,
        lib,
        pkgs,
        ...
      }:
      let
        media = import ./_media.nix host.mediaRoot;
        inherit (media) group;
        mediaDir = media.mediaDir media.categories.series;
      in
      lib.mkMerge [
        (import ./_arr.nix {
          inherit lib group dataDir;
          name = "sonarr";
          title = "Sonarr";
          port = webPort;
        } config)
        {
          users.groups.${group} = { };

          services.sonarr = {
            enable = true;
            package = pkgs.unstable.sonarr;
            user = "sonarr";
            inherit group dataDir;
            # nginx is the ingress; opening the port here would let clients bypass it.
            settings.server.port = webPort;
            openFirewall = false;
          };

          systemd.tmpfiles.rules = [
            "d ${dataDir} 0755 sonarr ${group} -"
            "d ${media.mediaRoot} 0775 sonarr ${group} -"
            "d ${mediaDir} 0775 sonarr ${group} -"
          ];

          environment.systemPackages = [ pkgs.unstable.sonarr ];
        }
      ];
  };
}
