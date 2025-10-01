{
  lib,
  config,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.roles.smart-home;

in
{
  options.${namespace}.roles.smart-home = {
    enable = mkEnableOption "Enable smart home role with Home Assistant and Zigbee support.";
  };

  config = mkIf cfg.enable {

    ${namespace} = {
      services = {

        smart-home = {
          home-assistant = {
            enable = true;
          };
        };

      };

    };

  };
}
