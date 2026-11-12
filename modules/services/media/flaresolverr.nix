{ config, ... }:
let
  c = (config.builders.testNixos config.flake.modules.nixos.flaresolverr).config;
in
{
  # Solves the Cloudflare challenges that indexers behind it put up, as
  # Prowlarr's indexer proxy.
  flake.modules.nixos.flaresolverr =
    { config, pkgs, ... }:
    {
      services.flaresolverr = {
        enable = true;
        package = pkgs.unstable.flaresolverr;
        port = config.constants.network.ports.flaresolverr.web;
      };

      # Upstream listens on all interfaces; only the indexer manager talks to it.
      systemd.services.flaresolverr.environment.HOST = "127.0.0.1";
    };

  evalTests.flaresolverr-loopback = {
    expr = {
      inherit (c.services.flaresolverr) port openFirewall;
      inherit (c.systemd.services.flaresolverr.environment) HOST;
    };
    expected = {
      port = 8191;
      openFirewall = false;
      HOST = "127.0.0.1";
    };
  };
}
