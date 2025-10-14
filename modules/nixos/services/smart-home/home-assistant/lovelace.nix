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
  ] ++ cfg.views;
}
