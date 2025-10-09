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
