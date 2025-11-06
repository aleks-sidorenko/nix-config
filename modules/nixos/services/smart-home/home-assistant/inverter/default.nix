# Deye Inverter Integration via Solarman
#
# This module configures Home Assistant to monitor Deye solar inverters
# using the Solarman custom component.
#
# IMPORTANT: This module requires the Solarman custom component to be installed
# in Home Assistant. Install it via HACS or manually:
# https://github.com/StephanJoubert/home_assistant_solarman
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
in
{
  options.${namespace}.services.smart-home.home-assistant.inverter = {
    enable = mkEnableOption "Enable Deye inverter integration via Solarman";

    ipAddress = mkOption {
      type = types.str;
      description = "IP address of the Solarman logger device";
      example = "192.168.1.100";
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
      default = "deye_sg05lp3";
      description = "Inverter model identifier for Solarman";
      example = "deye_sg04lp3";
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
      # Solarman is a custom component, so we need to add it to customComponents
      # For now, we'll document that users need to install it manually via HACS
      # or we can package it ourselves
      
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
            {
              type = "entities";
              title = "Inverter Status";
              show_header_toggle = false;
              entities = [
                {
                  entity = "sensor.solarman_total_production";
                  name = "Total Production";
                }
                {
                  entity = "sensor.solarman_today_production";
                  name = "Today's Production";
                }
                {
                  entity = "sensor.solarman_current_power";
                  name = "Current Power";
                }
              ];
            }
            {
              type = "entities";
              title = "Grid Status";
              show_header_toggle = false;
              entities = [
                {
                  entity = "sensor.solarman_grid_voltage";
                  name = "Grid Voltage";
                }
                {
                  entity = "sensor.solarman_grid_frequency";
                  name = "Grid Frequency";
                }
                {
                  entity = "sensor.solarman_grid_power";
                  name = "Grid Power";
                }
              ];
            }
            {
              type = "entities";
              title = "Battery Status";
              show_header_toggle = false;
              entities = [
                {
                  entity = "sensor.solarman_battery_soc";
                  name = "Battery SOC";
                }
                {
                  entity = "sensor.solarman_battery_voltage";
                  name = "Battery Voltage";
                }
                {
                  entity = "sensor.solarman_battery_power";
                  name = "Battery Power";
                }
                {
                  entity = "sensor.solarman_battery_temperature";
                  name = "Battery Temperature";
                }
              ];
            }
            {
              type = "history-graph";
              title = "Power History";
              entities = [
                {
                  entity = "sensor.solarman_current_power";
                }
                {
                  entity = "sensor.solarman_grid_power";
                }
                {
                  entity = "sensor.solarman_battery_power";
                }
              ];
              hours_to_show = 24;
            }
          ];
        }
      ];
    };

    # Create Solarman configuration package
    systemd.services.home-assistant.preStart =
      let
        solarmanYaml = pkgs.writeText "inverter.yaml" ''
          # Solarman integration for Deye inverter
          # Note: This requires the Solarman custom component to be installed
          # Install via HACS or manually place in custom_components/solarman/
          
          solarman:
            - name: "Solarman"
              ip_address: "${cfg.ipAddress}"
              serial: ${cfg.serialNumber}
              port: ${toString cfg.port}
              mb_slave_id: 1
              lookup_file: "${cfg.inverterModel}.yaml"
              scan_interval: ${toString cfg.updateInterval}
        '';
      in
      ''
        ln -fns ${solarmanYaml} ${haCfg.dataDir}/packages/inverter.yaml
      '';
  };
}

