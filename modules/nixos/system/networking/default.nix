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
  localIp = last: "10.0.0.${toString last}";
  staticIp = host: last: {
    "${localIp last}" = [
      "${host}"
      "${host}.${cfg.domains.local}"
    ];
  };
in
{
  options.${namespace}.system.networking = with types; {
    enable = mkBoolOpt false "Enable networking";
    domains = {
      local = mkOpt str "local" "Local domain for intranet resolution";
      public = mkOpt str "sidorenko.me" "Public domain to search for";
    };

  };

  config = mkIf cfg.enable (
    {
      networking = {
        # Enable NetworkManager to manage the network interfaces
        useDHCP = mkDefault true;
        # Enable NetworkManager to manage the network interfaces
        networkmanager.enable = true;
        # Disable wireless networking since it conflicts with the networkmanager
        wireless.enable = false;

        search = mkForce [
          cfg.domains.local
          cfg.domains.public
        ];
        hosts = mkForce (staticIp "server" 40);

        firewall = {
          enable = false; # TODO: enable firewall
        };
      };

    }
    // (persistence.persistentDirectories config [
      "/etc/NetworkManager/system-connections"
    ])
  );
}
