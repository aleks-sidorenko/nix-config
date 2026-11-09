{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services.media.flaresolverr;

in
{
  options.${namespace}.services.media.flaresolverr = {
    enable = mkEnableOption "Enable FlareSolverr, which solves Cloudflare challenges for indexers behind it";

    package = mkOpt types.package pkgs.unstable.flaresolverr "FlareSolverr package to use";

    port =
      mkOpt types.port defaults.network.ports.flaresolverr.web
        "Port for FlareSolverr to listen on";
  };

  config = mkIf cfg.enable {
    services.flaresolverr = {
      inherit (cfg) enable package port;
    };

    # Upstream listens on all interfaces by default; only local indexer managers talk to it.
    systemd.services.flaresolverr.environment.HOST = "127.0.0.1";
  };
}
