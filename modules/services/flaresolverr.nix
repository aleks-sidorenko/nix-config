{ config, den, ... }:
let
  port = 8191;

  inherit (config.installTests) perTestedHost;
in
{
  den.aspects.services.flaresolverr = {
    # Without fonts its browser aborts at launch; the service itself is off in
    # the test VM (below).
    installChecks = [ ''machine.succeed("test -e /etc/fonts/fonts.conf")'' ];

    nixos =
      { lib, pkgs, ... }:
      {
        services.flaresolverr = {
          enable = true;
          package = pkgs.unstable.flaresolverr;
          inherit port;
        };

        # Upstream listens on all interfaces; only local indexer managers talk to it.
        systemd.services.flaresolverr.environment.HOST = "127.0.0.1";

        # Its browser's font manager aborts without /etc/fonts.
        fonts.fontconfig.enable = true;

        # The test VM's 1 GB can't fit the browser beside every other service;
        # it only swaps until its own startup check times out.
        installTest.extraConfig.services.flaresolverr.enable = lib.mkForce false;
      };
  };

  evalTests.flaresolverr-fontconfig = perTestedHost den.aspects.services.flaresolverr (
    _: host: (config.installTests.installedSystem host).config.fonts.fontconfig.enable
  ) true;
}
