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
  
  # Get all temperature sensors from devices
  devices = config.${namespace}.services.smart-home.devices.all;
  temperatureSensors = builtins.filter (d: d.type == "temperature") devices;
  
  # Generate entity IDs for temperature and humidity sensors
  mkTemperatureEntities = device: [
    {
      entity = "sensor.${device.id}_temperature";
      name = mkFriendlyName [ device.zone.friendly_name "Temperature"];
    }
    {
      entity = "sensor.${device.id}_humidity";
      name = mkFriendlyName [ device.zone.friendly_name "Humidity"];
    }
  ];
  
  # Flatten the list of all temperature/humidity entities
  temperatureEntities = builtins.concatMap mkTemperatureEntities temperatureSensors;
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

      # Add zigbee2mqtt views to dashboard
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
      ] ++ (optionals (temperatureEntities != []) [
        {
          title = "Temperature";
          path = "temperature";
          icon = "mdi:thermometer";
          cards = [
            {
              type = "entities";
              title = "Temperature & Humidity Sensors";
              show_header_toggle = false;
              entities = temperatureEntities;
            }
            {
              type = "history-graph";
              title = "Temperature History";
              hours_to_show = 24;
              entities = map (e: e.entity) (builtins.filter (e: lib.hasSuffix "_temperature" e.entity) temperatureEntities);
            }
            {
              type = "history-graph";
              title = "Humidity History";
              hours_to_show = 24;
              entities = map (e: e.entity) (builtins.filter (e: lib.hasSuffix "_humidity" e.entity) temperatureEntities);
            }
          ];
        }
      ]);

      config.mqtt = {};

    };
             
    systemd.services.home-assistant.preStart = ''
      ln -fns ${./zigbee2mqtt.yaml} ${haCfg.dataDir}/packages/zigbee2mqtt.yaml
    '';
  };
}
