# Deye Inverter Integration via Solarman
#
# This module configures Home Assistant to monitor Deye solar inverters
# using the Solarman custom component.
#
# The Solarman custom component is automatically installed when this module is enabled.
#
# See README.md in this directory for detailed setup instructions.
{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:
with lib;
with lib.${namespace};
let
  haCfg = config.${namespace}.services.smart-home.home-assistant;
  cfg = haCfg.inverter;

  # Solarman custom component package
  solarman = pkgs.buildHomeAssistantComponent rec {
    owner = "davidrapan";
    domain = "solarman";
    version = "25.08.16";

    src = pkgs.fetchFromGitHub {
      owner = "davidrapan";
      repo = "ha-solarman";
      rev = "v${version}";
      sha256 = "sha256-SsUObH3g3i9xQ4JvRDcCm1Fg2giH+MN3rC3NMPYO5m0=";
      # just github-fetch-hash davidrapan ha-solarman v25.08.16
    };
    dependencies = with pkgs.home-assistant.python.pkgs; [
      aiohttp
      aiofiles
      propcache
      pyyaml
      umodbus
    ];
    meta = with lib; {
      description = "Home Assistant integration for Solarman data loggers";
      homepage = "https://github.com/davidrapan/ha-solarman";
      changelog = "https://github.com/davidrapan/ha-solarman/releases/tag/v${version}";
      license = licenses.mit;
      maintainers = with maintainers; [ ];
    };
  };
in
{
  options.${namespace}.services.smart-home.home-assistant.inverter = {
    enable = mkEnableOption "Enable Deye inverter integration via Solarman";

    host = mkOption {
      type = types.str;
      description = "Host name or IP address of the Solarman logger device";
      example = "10.0.0.100";
      default = hosts.local "inverter";
    };

    serialNumber = mkOption {
      type = types.str;
      description = "Serial number of the Solarman logger";
      example = "123456789";
    };

    port = mkOption {
      type = types.port;
      default = 8899;
      description = "Port for Solarman communication";
    };

    inverterModel = mkOption {
      type = types.str;
      default = "deye_p3";
      description = "Inverter model identifier for Solarman";
      example = "deye_p3";
    };

    updateInterval = mkOption {
      type = types.int;
      default = 60;
      description = "Update interval in seconds";
    };
  };

  config = mkIf (haCfg.enable && cfg.enable) {
    # No secrets needed for basic Solarman integration
    # If password is required in the future, add SOPS secrets here

    services.home-assistant = {
      # Install Solarman custom component
      customComponents = [
        solarman
      ];

      # Solarman needs these base components
      extraComponents = [
        "sensor"
        "switch"
      ];

      # Add inverter view to dashboard
      lovelaceConfig.views = [
        {
          title = "Solar Inverter";
          path = "inverter";
          icon = "mdi:solar-power";
          cards = [
            # Grid Status Card
            {
              type = "entities";
              title = "Grid Status";
              entities = [
                "binary_sensor.inverter_grid"
                "sensor.inverter_grid_l1_voltage"
                "sensor.inverter_grid_l2_voltage"
                "sensor.inverter_grid_l3_voltage"
                "sensor.inverter_grid_frequency"
                "sensor.inverter_grid_power"
              ];
            }
            # Battery Status Card
            {
              type = "entities";
              title = "Battery Status";
              entities = [
                "sensor.inverter_battery"
                "sensor.inverter_battery_power"
                "sensor.inverter_battery_temperature"
                "sensor.inverter_battery_voltage"
                "sensor.inverter_total_battery_life_cycles"
              ];
            }
            # Power Production Card
            {
              type = "entities";
              title = "Power Production";
              entities = [
                "sensor.inverter_total_production"
                "sensor.inverter_today_production"
              ];
            }
            # Solar Panels Card
            {
              type = "entities";
              title = "Solar Panels";
              entities = [
                "sensor.inverter_pv1_voltage"
                "sensor.inverter_pv1_current"
                "sensor.inverter_pv1_power"
                "sensor.inverter_pv2_voltage"
                "sensor.inverter_pv2_current"
                "sensor.inverter_pv2_power"
              ];
            }
            # Inverter Status Card
            {
              type = "entities";
              title = "Inverter Status";
              entities = [
                "sensor.inverter_device"
                "sensor.inverter_device_state"
                "sensor.inverter_temperature"
              ];
            }
            # Power Flow Card (if available)
            {
              type = "gauge";
              entity = "sensor.inverter_grid_power";
              name = "Grid Power";
              min = -10000;
              max = 10000;
              severity = {
                green = -10000;
                yellow = 0;
                red = 5000;
              };
            }
            # Grid Notifications Card
            {
              type = "entities";
              title = "Grid Notifications";
              show_header_toggle = false;
              entities = [
                {
                  entity = "input_boolean.telegram_grid_notifications";
                  name = "Enable Notifications";
                }
              ];
              footer = {
                type = "buttons";
                entities = [
                  {
                    entity = "input_button.telegram_grid_manual_notification";
                    name = "Send Notification";
                    icon = "mdi:send";
                    tap_action = {
                      action = "call-service";
                      service = "input_button.press";
                      target = {
                        entity_id = "input_button.telegram_grid_manual_notification";
                      };
                    };
                  }
                ];
              };
            }
          ];
        }
      ];
    };

    # Ensure custom_components directory exists with proper permissions
    systemd.tmpfiles.rules = [
      "d ${haCfg.dataDir}/custom_components 0755 ${haCfg.user} ${haCfg.group} -"
    ];

  };
}
