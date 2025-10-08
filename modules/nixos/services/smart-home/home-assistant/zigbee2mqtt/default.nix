{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  haCfg = config.${namespace}.services.smart-home.home-assistant;
  cfg = haCfg.zigbee2mqtt;
in
{
  options.${namespace}.services.smart-home.home-assistant.zigbee2mqtt = {
    enable = mkBoolOpt config.services.zigbee2mqtt.enable "Enable zigbee2mqtt integration and dashboard";
  };

  config = mkIf (haCfg.enable && cfg.enable) {
    services.home-assistant = {

      extraComponents = [
        "mqtt"
        "zha" # not used, but causes error if missing
      ];

      # Add zigbee2mqtt view to dashboard
      lovelaceConfig.views = [
        {
          title = "Settings";
          path = "settings";
          icon = "mdi:cog";
          cards = [
            {
              type = "entities";
              show_header_toggle = false;
              entities = [
                { entity = "sensor.zigbee2mqtt_bridge_state"; }
                { entity = "sensor.zigbee2mqtt_version"; }
                { entity = "sensor.zigbee2mqtt_coordinator_version"; }
                { entity = "input_select.zigbee2mqtt_log_level"; }
                { type = "divider"; }
                { entity = "switch.zigbee2mqtt_main_join"; }
                { entity = "input_number.zigbee2mqtt_join_minutes"; }
                { entity = "timer.zigbee_permit_join"; }
              ];
            }
          ];
        }
      ];

      config.mqtt = { };

    };
             
    systemd.services.home-assistant.preStart = ''
      ln -fns ${./zigbee2mqtt.yaml} ${haCfg.dataDir}/packages/zigbee2mqtt.yaml
    '';
  };
}
