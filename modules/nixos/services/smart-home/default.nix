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
  enabled = cfg.home-assistant.enable || cfg.zigbee2mqtt.enable;

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
