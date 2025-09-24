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

  staticIp = host: {
    "${defaults.network.hosts.${host}}" = [
      "${host}"
      "${host}.${cfg.domains.local}"
    ];
  };
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
      hosts = mkForce (lib.mkMerge (lib.mapAttrsToList (host: _: staticIp host) defaults.network.hosts));

      firewall = {
        enable = false; # TODO: enable firewall
      };
    };
    environment.persistence.${persistence.root config}.directories = [
      "/etc/NetworkManager/system-connections"
    ];
  };

}
