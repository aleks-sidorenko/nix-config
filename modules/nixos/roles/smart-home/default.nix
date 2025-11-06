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
            weather = enabled;
            heatpump = enabled;
            tv = enabled;
            night-schedule = enabled;
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
