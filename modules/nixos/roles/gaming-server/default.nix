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
          minecraft-server = enabled;
        };
      };
    };
  };
}


