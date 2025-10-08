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
  };

  config = mkIf (haCfg.enable && cfg.enable) {
    services.home-assistant = {
      # Add weather components to Home Assistant
      extraComponents = [
        "met" # Norwegian Meteorological Institute weather
        "sun" # Sun rise/set tracking
        "moon" # Moon phase tracking
      ];

      # Add weather view to dashboard
      lovelaceConfig.views = [
        {
          title = "Weather";
          path = "weather";
          icon = "mdi:weather-partly-cloudy";
          cards = [
            {
              type = "weather-forecast";
              entity = "weather.forecast_home_2";
              show_forecast = true;
            }
            {
              type = "entities";
              title = "Sun ";
              entities = [ "sun.sun" ];
            }
            {
              type = "entities";
              title = "Moon";
              entities = [ "moon.phase" ];
            }
          ];
        }
      ];

      # Enable sun component
      config.sun = {};        
    };
  };
}
