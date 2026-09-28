{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.system.networking;
in
{
  options.${namespace}.system.networking = with types; {
    enable = mkBoolOpt false "Enable networking";
    knownNetworkServices = mkOpt (listOf str) [ "Wi-Fi" ] "List of macOS network services to configure";
    domains = {
      lan = mkOpt str defaults.network.domains.lan "LAN domain for intranet resolution";
      public = mkOpt str defaults.network.domains.public "Public domain to search for";
    };
  };

  config = mkIf cfg.enable {
    networking = {
      inherit (cfg) knownNetworkServices;

      dns = [
        "1.1.1.1"
        "8.8.8.8"
      ];

      search = [
        defaults.network.domains.tailnet
        cfg.domains.lan
      ];
    };
  };
}
