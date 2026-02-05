{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};

let
  cfg = config.${namespace}.roles.communication;
in
{
  options.${namespace}.roles.communication = {
    enable = mkEnableOption "Whether to enable the communication suite";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      communication = {
        telegram = enabled;
        viber = enabled;        
      };
    };

  };
}
