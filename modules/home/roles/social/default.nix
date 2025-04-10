{
  pkgs,
  config,
  lib,
  namespace,
  ...
}:
with lib;
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
        discord.enable = true;
        shotwell.enable = true;
      };
    };

  };
}
