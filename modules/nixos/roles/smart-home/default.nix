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
            night-schedule = enabled;

            weather = enabled;
            heatpump = enabled;
            climate = enabled;
            plugs = {
              enable = true;
              plugs = [
                {
                  enable = true;
                  name = "tv";
                  displayName = "TV";
                  entity_id = "switch.floor1_living_plug_tv";
                  intervals = [
                    {
                      name = "morning";
                      start = "07:30";
                      end = "09:30";
                    }
                    {
                      name = "evening";
                      start = "18:00";
                      end = "19:30";
                    }
                    {
                      name = "night";
                      start = "22:00";
                      end = "01:00";
                    }
                  ];
                }
                {
                  enable = true;
                  name = "fireplace";
                  displayName = "Fireplace";
                  entity_id = "switch.floor1_living_plug_fireplace";
                  intervals = [
                    {
                      name = "default";
                      start = "08:00";
                      end = "23:59";
                    }
                  ];
                }
                {
                  enable = true;
                  name = "hall_mirror";
                  displayName = "Hall Mirror";
                  entity_id = "switch.floor2_hall_plug_mirror";
                  intervals = [
                    {
                      name = "default";
                      start = "08:00";
                      end = "22:59";
                    }
                  ];
                }

                {
                  enable = true;
                  name = "kids_door";
                  displayName = "Kids Door";
                  entity_id = "switch.floor2_kids_plug_door";
                  intervals = [
                    {
                      name = "default";
                      start = "08:00";
                      end = "22:59";
                    }
                  ];
                }
              ];
            };
            inverter = {
              enable = true;
              serialNumber = "2988661222";
            };
            telegram-notifications = {
              enable = true;
              notifyOnStartup = false;
            };
          };
          mosquitto = enabled;
          zigbee2mqtt = {
            enable = true;
            device = "/dev/serial/by-id/usb-ITEAD_SONOFF_Zigbee_3.0_USB_Dongle_Plus_V2_20220713100628-if00";
            adapter = "ember";
          };
        };

      };

    };

  };
}
