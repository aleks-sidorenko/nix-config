{ cfg }:
{
  title = "Home";
  views = [
    {
      title = "Overview";
      path = "default_view";
      icon = "mdi:home";
      cards = [
        {
          type = "weather-forecast";
          entity = "weather.forecast_home_2";
          show_forecast = true;
        }
        {
          type = "entities";
          title = "Plugs & Switches";
          entities = [
            {
              entity = "switch.basement_boiler_plug_boiler";
              name = "Boiler";
              icon = "mdi:water-boiler";
            }
            {
              entity = "switch.floor1_living_plug_tv";
              name = "Living Room TV";
              icon = "mdi:television";
            }
            {
              entity = "switch.floor2_shower_switch_fan";
              name = "Shower Fan";
              icon = "mdi:fan";
            }
          ];
          footer = {
            type = "buttons";
            entities = [
              {
                entity = "sensor.zigbee2mqtt_bridge_state";
                name = "View Plugs";
                tap_action = {
                  action = "navigate";
                  navigation_path = "/lovelace/plugs";
                };
              }
              {
                entity = "sensor.zigbee2mqtt_bridge_state";
                name = "View Switches";
                tap_action = {
                  action = "navigate";
                  navigation_path = "/lovelace/switches";
                };
              }
            ];
          };
        }
        {
          type = "entities";
          title = "System Information";
          entities = [
            "sun.sun"
            "sensor.time"
          ];
        }
        {
          type = "glance";
          title = "Quick Access";
          entities = [
            "sun.sun"
            "sensor.time"
          ];
        }
      ];
    }
  ]
  ++ cfg.views;
}
