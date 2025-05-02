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
  impermanenceCfg = config.${namespace}.system.impermanence;
in
{
  options.${namespace}.system.networking = with types; {
    enable = mkBoolOpt false "Enable networkmanager";
  };

  config = mkIf cfg.enable {
    networking = {     
      # Enable NetworkManager to manage the network interfaces
      useDHCP = mkDefault true;
      # Enable NetworkManager to manage the network interfaces
      networkmanager.enable = true;

      # Disable wireless networking since it conflicts with the networkmanager   
      wireless.enable = false; 
    };

    environment.persistence."/persist".directories = mkIf impermanenceCfg.enable [
      "/etc/NetworkManager/system-connections"
    ];
  };
}
