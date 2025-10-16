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

  # Get all devices
  devices = config.${namespace}.services.smart-home.devices.all;

  # Filter devices by type
  temperatureSensors = builtins.filter (d: d.type == "temperature") devices;
  plugs = builtins.filter (d: d.type == "plug") devices;
  switches = builtins.filter (d: d.type == "switch") devices;

  # Generate entity IDs for temperature and humidity sensors
  mkTemperatureEntities = device: [
    {
      entity = "sensor.${device.id}_temperature";
      name = mkFriendlyName [
        device.zone.friendly_name
        "temperature"
      ];
    }
    {
      entity = "sensor.${device.id}_humidity";
      name = mkFriendlyName [
        device.zone.friendly_name
        "humidity"
      ];
    }
  ];

  # Generate entity IDs for plugs
  mkPlugEntities = device: [
    {
      entity = "switch.${device.id}";
      name = device.friendly_name;
    }
  ];

  # Generate entity IDs for switches
  mkSwitchEntities = device: [
    {
      entity = "switch.${device.id}";
      name = device.friendly_name;
    }
  ];

  # Group temperature sensors by zone with section headers
  groupSensorsByZone =
    sensors:
    let
      # Sort sensors by floor first, then by zone
      sortedSensors = builtins.sort (
        a: b:
        if a.zone.floor == b.zone.floor then a.zone.zone < b.zone.zone else a.zone.floor < b.zone.floor
      ) sensors;

      # Get unique zone IDs in sorted order
      zoneIds = lib.unique (map (s: s.zone.id) sortedSensors);

      # Create entities list with zone section headers
      mkZoneEntities =
        zoneId:
        let
          zoneSensors = builtins.filter (s: s.zone.id == zoneId) sortedSensors;
          firstSensor = builtins.head zoneSensors;
          entities = builtins.concatMap mkTemperatureEntities zoneSensors;
        in
        [
          {
            type = "section";
            label = firstSensor.zone.friendly_name;
          }
        ]
        ++ entities;
    in
    builtins.concatMap mkZoneEntities zoneIds;

  # Flatten the list of all temperature/humidity entities
  temperatureEntities = builtins.concatMap mkTemperatureEntities temperatureSensors;

  # Flatten the list of all plug entities
  plugEntities = builtins.concatMap mkPlugEntities plugs;

  # Flatten the list of all switch entities
  switchEntities = builtins.concatMap mkSwitchEntities switches;
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
      lovelaceConfig.views =
        [
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
        ]
        ++ (optionals (temperatureSensors != [ ]) [
          {
            title = "Temperature";
            path = "temperature";
            icon = "mdi:thermometer";
            cards = [
              {
                type = "entities";
                title = "Temperature & Humidity Sensors";
                show_header_toggle = false;
                entities = groupSensorsByZone temperatureSensors;
              }
              {
                type = "history-graph";
                title = "Temperature History";
                hours_to_show = 24;
                entities = map (e: e.entity) (
                  builtins.filter (e: lib.hasSuffix "_temperature" e.entity) temperatureEntities
                );
              }
              {
                type = "history-graph";
                title = "Humidity History";
                hours_to_show = 24;
                entities = map (e: e.entity) (
                  builtins.filter (e: lib.hasSuffix "_humidity" e.entity) temperatureEntities
                );
              }
            ];
          }
        ])
        ++ (optionals (plugEntities != [ ]) [
          {
            title = "Plugs";
            path = "plugs";
            icon = "mdi:power-plug";
            cards = [
              {
                type = "entities";
                title = "Smart Plugs";
                show_header_toggle = true;
                entities = plugEntities;
              }
              {
                type = "history-graph";
                title = "Plug State History";
                hours_to_show = 24;
                entities = map (e: e.entity) plugEntities;
              }
            ];
          }
        ])
        ++ (optionals (switchEntities != [ ]) [
          {
            title = "Switches";
            path = "switches";
            icon = "mdi:toggle-switch";
            cards = [
              {
                type = "entities";
                title = "Switches";
                show_header_toggle = true;
                entities = switchEntities;
              }
              {
                type = "history-graph";
                title = "Switch State History";
                hours_to_show = 24;
                entities = map (e: e.entity) switchEntities;
              }
            ];
          }
        ]);

      config.mqtt = { };

    };

    systemd.services.home-assistant.preStart = ''
      ln -fns ${./zigbee2mqtt.yaml} ${haCfg.dataDir}/packages/zigbee2mqtt.yaml
    '';
  };
}
