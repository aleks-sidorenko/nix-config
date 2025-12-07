{
  lib,
  config,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.gaming-server;
in
{
  options.${namespace}.roles.gaming-server = {
    enable = mkEnableOption "Enable gaming server role.";
  };

  config = mkIf cfg.enable {
    ${namespace} = {      
      services = {
        gaming = {          
          minecraft-server = {
            enable = true;
            ops = [
              {
                uuid = "036251c9-562e-48b6-af54-1ae7a154c01f"; # https://mcuuid.net/?q=s1dus
                name = "s1dus";
                level = 4;
                bypassesPlayerLimit = true;
              }
            ];
          };
        };
      };
    };
  };
}


