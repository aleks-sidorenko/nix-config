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
  impermanenceCfg = config.${namespace}.disks.impermanence;
in
{
  options.${namespace}.system.networking = with types; {
    enable = mkBoolOpt false "Enable networkmanager";     
    domains = mkOpt (types.listOf types.str) [ "local", "sidorenko.me" ] "Domains to search for";
  };

  config = mkIf cfg.enable {
    networking = {
      # Enable NetworkManager to manage the network interfaces
      useDHCP = mkDefault true;
      # Enable NetworkManager to manage the network interfaces
      networkmanager.enable = true;
      # Disable wireless networking since it conflicts with the networkmanager
      wireless.enable = false;

      search = cfg.domains;

      firewall = {
        enable = false; # TODO: enable firewall        
      };
    };

    environment.persistence."/persist".directories = mkIf impermanenceCfg.enable [
      "/etc/NetworkManager/system-connections"
    ];
  };
}
