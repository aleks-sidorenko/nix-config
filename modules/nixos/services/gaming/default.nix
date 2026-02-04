{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services.gaming;
  enabled = cfg.minecraft-server.enable;
in
{
  options.${namespace}.services.gaming = {
    enable = mkBoolOpt enabled "Enable gaming services";
    group = mkOpt types.str "gaming" "Group to run gaming services as";
  };

  config = mkIf cfg.enable {
    users.groups.${cfg.group} = mkDefault { };
  };
}
