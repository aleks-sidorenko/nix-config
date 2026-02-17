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
    domains = {
      local = mkOpt str defaults.network.domains.local "Local domain for intranet resolution";
      public = mkOpt str defaults.network.domains.public "Public domain to search for";
    };
  };

  config = mkIf cfg.enable {
    networking = {
      knownNetworkServices = [
        "Wi-Fi"
      ];
    };

    # Blocked by https://github.com/nix-darwin/nix-darwin/issues/1035
    environment.etc."hosts" = {
      text =
        let
          hostsEntries = lib.mapAttrsToList (
            host: ip: "${ip} ${host} ${host}.${cfg.domains.local}"
          ) defaults.network.hosts;
        in
        ''
          ##
          # Host Database
          ##
          127.0.0.1 localhost
          255.255.255.255 broadcasthost
          ::1 localhost

          # Local network hosts
        ''
        + lib.concatStringsSep "\n" hostsEntries
        + "\n";
    };
  };
}
