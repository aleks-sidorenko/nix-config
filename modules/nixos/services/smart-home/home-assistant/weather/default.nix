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
  cfg = haCfg.weather;
in
{
  options.${namespace}.services.smart-home.home-assistant.weather = {
    enable = mkEnableOption "Enable weather integration and dashboard";

    showForecast = mkOption {
      type = types.bool;
      default = true;
      description = "Show weather forecast on dashboard";
    };

    showSun = mkOption {
      type = types.bool;
      default = true;
      description = "Show sun rise/set information on dashboard";
    };
  };

  config = mkIf (haCfg.enable && cfg.enable) {
    ${namespace}.services.smart-home.home-assistant = {
      # Add weather components to Home Assistant
      extraComponents = [
        "met" # Norwegian Meteorological Institute weather
        "sun" # Sun rise/set tracking
      ];

      # Add weather view to dashboard
      lovelaceConfig.views = [
        {
          title = "Weather";
          path = "weather";
          icon = "mdi:weather-partly-cloudy";
          cards = lists.flatten [
            (optional weatherCfg.showForecast {
              type = "weather-forecast";
              entity = "weather.home";
              show_forecast = true;
            })
            (optional weatherCfg.showSun {
              type = "entities";
              title = "Sun";
              entities = [ "sun.sun" ];
            })
          ];
        }
      ];
    };
  };
}
