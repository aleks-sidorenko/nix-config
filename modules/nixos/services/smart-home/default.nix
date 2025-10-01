{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services.smart-home;
  enabled = config.${namespace}.services.smart-home.home-assistant.enable;

in
{
  options.${namespace}.services.smart-home = {
    enable = mkBoolOpt enabled "Enable smart home services.";
    group = mkOpt types.str "smart-home" "Group to run smart home services as";
  };

  config = mkIf cfg.enable {
    # Create the shared smart-home group
    users.groups.${cfg.group} = mkDefault { };

  };

}
