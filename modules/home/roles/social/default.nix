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
  cfg = config.${namespace}.roles.social;
in
{
  options.${namespace}.roles.social = {
    enable = mkEnableOption "Enable social suite";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      apps = {
        telegram = enabled;
        viber = enabled;
      };
    };

  };
}
