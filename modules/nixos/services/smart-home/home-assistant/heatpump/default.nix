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
  cfg = haCfg.heatpump;

  modeType = types.submodule {
    options = {
      temperature_from = mkOption {
        type = types.int;
        description = "Lower temperature threshold in °C";
      };
      temperature_to = mkOption {
        type = types.int;
        description = "Upper temperature threshold in °C";
      };
    };
  };
in
{
  options.${namespace}.services.smart-home.home-assistant.heatpump = {
    enable = mkEnableOption "Enable heatpump integration and dashboard";

    gridStatusSensor = mkOption {
      type = types.str;
      default = "binary_sensor.grid_status_debounced";
      description = "Entity ID of the grid status sensor to monitor";
      example = "binary_sensor.grid_status_debounced";
    };

    batterySocSensor = mkOption {
      type = types.str;
      default = "sensor.inverter_battery";
      description = "Entity ID of the battery state of charge sensor";
      example = "sensor.inverter_battery";
    };

    batteryMinimalSOC = mkOption {
      type = types.int;
      default = 70;
      description = "Minimum battery SOC percentage required to allow heatpump operation during grid off";
      example = 50;
    };

    gridOnly = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to automatically react to grid_on and grid_off events";
    };

    nightMode = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to automatically react to night schedule on and off events";
    };

    modes = {
      off = mkOption {
        type = modeType;
        default = {
          temperature_from = 15;
          temperature_to = 18;
        };
        description = "Off heating mode";
      };

      on = mkOption {
        type = modeType;
        default = {
          temperature_from = 24;
          temperature_to = 27;
        };
        description = "On heating mode";
      };
    };
  };

  config = mkIf (haCfg.enable && cfg.enable) {
    # Configure SOPS secrets for ThingSpeak
    sops.secrets."service-home-assistant-heatpump-channel" = {
      sopsFile = ../../../../secrets.yaml;
      owner = haCfg.user;
      group = haCfg.group;
      mode = "0440";
      restartUnits = [ "home-assistant.service" ];
    };

    sops.secrets."service-home-assistant-heatpump-api-key" = {
      sopsFile = ../../../../secrets.yaml;
      owner = haCfg.user;
      group = haCfg.group;
      mode = "0440";
      restartUnits = [ "home-assistant.service" ];
    };

    # Register secrets with main Home Assistant module
    ${namespace} = {
      services.smart-home.home-assistant.secrets = {
        thingspeak_channel = config.sops.secrets."service-home-assistant-heatpump-channel".path;
        thingspeak_api_key = config.sops.secrets."service-home-assistant-heatpump-api-key".path;
      };
    };

    services.home-assistant = {

      extraComponents = [
        "rest"
        "rest_command"
      ];

      # Add heatpump view to dashboard
      lovelaceConfig.views = [
        {
          title = "Heatpump";
          path = "heatpump";
          icon = "mdi:heat-pump";
          cards = [
            {
              type = "entities";
              title = "Heatpump Status";
              show_header_toggle = false;
              entities = [
                {
                  entity = "sensor.heatpump_mode";
                  name = "Current Mode";
                }
                {
                  entity = "sensor.heatpump_temperature_from";
                  name = "Temperature From";
                }
                {
                  entity = "sensor.heatpump_temperature_to";
                  name = "Temperature To";
                }
                {
                  entity = "sensor.heatpump_supply_temperature";
                  name = "Supply Temperature";
                }
                {
                  entity = "sensor.heatpump_return_temperature";
                  name = "Return Temperature";
                }
                {
                  entity = "sensor.heatpump_overheat";
                  name = "Overheat";
                }
                {
                  entity = "sensor.heatpump_evaporation";
                  name = "Evaporation";
                }
                {
                  entity = "sensor.heatpump_last_update";
                  name = "Last Update";
                }
                {
                  entity = cfg.batterySocSensor;
                  name = "Battery: Current SOC";
                }
              ];
            }
            {
              type = "entities";
              title = "Heatpump Control";
              show_header_toggle = false;
              entities = [
                {
                  entity = "switch.heatpump";
                  name = "Heatpump";
                }
                {
                  entity = "input_boolean.heatpump_night_mode";
                  name = "Night Mode";
                }
                {
                  entity = "input_boolean.heatpump_grid_only";
                  name = "Grid Only";
                }
                {
                  entity = "input_number.heatpump_battery_minimal_soc";
                  name = "Battery: Minimal SOC";
                }
                {
                  entity = "input_number.heatpump_temperature_from";
                  name = "Temperature From";
                }
                {
                  entity = "input_number.heatpump_temperature_to";
                  name = "Temperature To";
                }
              ];
            }
            {
              type = "markdown";
              content = ''
                ## Heatpump Monitoring

                The following temperature sensors are monitored from ThingSpeak:
                - **Supply Temperature (СО)**: Heating system supply temperature (field1)
                - **Temperature From**: Lower temperature setpoint (field2)
                - **Temperature To**: Upper temperature setpoint (field3)
                - **Return Temperature (СО)**: Heating system return temperature (field4)
                - **Overheat**: Overheat temperature (field5)
                - **Evaporation**: Evaporation temperature (field6)

                ## Heatpump Schedule

                The heatpump temperatures are automatically adjusted based on:

                ### Night Schedule (optional)
                - **Night Mode**: Enable/disable automatic response to night schedule changes
                - **Night Schedule Off**: Uses Off Mode settings (configured in Nix) (when enabled)
                - **Night Schedule On**: Uses On Mode settings (adjustable above) (when enabled)

                ### Grid Status (optional)
                - **Grid Only**: Enable/disable automatic response to grid status changes
                - **Battery Minimal SOC**: Minimum battery percentage required for heatpump operation during grid off
                - **Grid Off**: Turns off heatpump (when enabled)
                - **Grid On**: Turns on heatpump (when enabled)
                - **Battery Protection**: Automatically turns off heatpump if battery drops below threshold during grid off

                You can adjust the On Mode temperatures using the controls above. Changes take effect when the night schedule status or grid status changes.
              '';
            }
          ];
        }
      ];

    };

    # Generate and link heatpump package configuration with templated values
    systemd.services.home-assistant.preStart = lib.mkAfter (
      let
        heatpumpYaml = pkgs.replaceVars ./heatpump.yaml {
          off_temperature_from = toString cfg.modes.off.temperature_from;
          off_temperature_to = toString cfg.modes.off.temperature_to;
          on_temperature_from = toString cfg.modes.on.temperature_from;
          on_temperature_to = toString cfg.modes.on.temperature_to;
          grid_status_sensor = cfg.gridStatusSensor;
          battery_soc_sensor = cfg.batterySocSensor;
          battery_minimal_soc = toString cfg.batteryMinimalSOC;
          grid_only = if cfg.gridOnly then "true" else "false";
          night_mode = if cfg.nightMode then "true" else "false";
        };
      in
      ''
        ln -fns ${heatpumpYaml} ${haCfg.dataDir}/packages/heatpump.yaml
      ''
    );
  };
}
