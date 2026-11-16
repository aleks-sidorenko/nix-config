let
  port = 8191;
in
{
  den.aspects.services.flaresolverr = {
    installChecks = [ ''machine.wait_for_unit("flaresolverr.service")'' ];

    nixos =
      { pkgs, ... }:
      {
        services.flaresolverr = {
          enable = true;
          package = pkgs.unstable.flaresolverr;
          inherit port;
        };

        # Upstream listens on all interfaces; only local indexer managers talk to it.
        systemd.services.flaresolverr.environment.HOST = "127.0.0.1";
      };
  };
}
