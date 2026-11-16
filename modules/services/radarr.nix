let
  webPort = (import ./_media.nix "").ports.radarr;
  dataDir = "/var/lib/radarr";
in
{
  den.aspects.services.radarr = {
    persist.directories = [ dataDir ];
    installChecks = [ ''machine.wait_for_unit("radarr.service")'' ];

    vhosts = [
      {
        name = "radarr";
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
        mediaDir = media.mediaDir media.categories.movies;
      in
      lib.mkMerge [
        (import ./_arr.nix {
          inherit lib group dataDir;
          name = "radarr";
          title = "Radarr";
          port = webPort;
        } config)
        {
          users.groups.${group} = { };

          services.radarr = {
            enable = true;
            package = pkgs.unstable.radarr;
            user = "radarr";
            inherit group dataDir;
            # nginx is the ingress; opening the port here would let clients bypass it.
            openFirewall = false;
            settings.server.port = webPort;
          };

          systemd.tmpfiles.rules = [
            "d ${dataDir} 0755 radarr ${group} -"
            "d ${media.mediaRoot} 0775 radarr ${group} -"
            "d ${mediaDir} 0775 radarr ${group} -"
          ];

          environment.systemPackages = [ pkgs.unstable.radarr ];
        }
      ];
  };
}
