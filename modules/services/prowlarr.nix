let
  webPort = 9696;
  # Upstream runs prowlarr as a dynamic user, so its state lives under the
  # private directory, which systemd keeps at 0700.
  dataDir = "/var/lib/private/prowlarr";
in
{
  den.aspects.services.prowlarr = {
    persist.directories = [ dataDir ];
    installChecks = [
      ''machine.wait_for_unit("prowlarr.service")''
      ''machine.succeed("test \"$(stat -c %a /var/lib/private)\" = 700")''
    ];

    vhosts = [
      {
        name = "prowlarr";
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
      in
      lib.mkMerge [
        (import ./_arr.nix {
          inherit lib group dataDir;
          name = "prowlarr";
          title = "Prowlarr";
          port = webPort;
        } config)
        {
          users.groups.${group} = { };

          services.prowlarr = {
            enable = true;
            package = pkgs.unstable.prowlarr;
            settings.server.port = webPort;
            # nginx is the ingress; opening the port here would let clients bypass it.
            openFirewall = false;
            # Upstream's dataDir option is broken for dynamic users
            # (nixpkgs#445983), so the default location is kept.
          };

          systemd.tmpfiles.rules = [ "d /var/lib/private 0700 root root -" ];

          environment.systemPackages = [ pkgs.unstable.prowlarr ];
        }
      ];
  };
}
