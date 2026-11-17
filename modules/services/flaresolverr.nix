{ config, den, ... }:
let
  port = 8191;

  inherit (config.installTests) perTestedHost;
in
{
  den.aspects.services.flaresolverr = {
    # The unit is up for a while before its browser check fails, so only the
    # port proves the browser started.
    installChecks = [ "machine.wait_for_open_port(${toString port}, timeout=180)" ];

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

        # Its browser's font manager aborts without /etc/fonts.
        fonts.fontconfig.enable = true;
      };
  };

  evalTests.flaresolverr-fontconfig = perTestedHost den.aspects.services.flaresolverr (
    _: host: (config.installTests.installedSystem host).config.fonts.fontconfig.enable
  ) true;
}
