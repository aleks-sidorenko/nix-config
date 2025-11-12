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
    owner = "StephanJoubert";
    domain = "solarman";
    version = "1.5.1";

    src = pkgs.fetchFromGitHub {
      owner = "StephanJoubert";
      repo = "home_assistant_solarman";
      rev = version;
      # To get the correct hash, run:
      # nix-shell -p nix-prefetch-github --run "nix-prefetch-github StephanJoubert home_assistant_solarman --rev 1.5.1"
      # Or build with lib.fakeHash and copy the hash from the error message
      hash = "sha256-+znRq7LGIxbxMEypIRqbIMgV8H4OyiOakmExx1aHEl8=";
    };

    # Solarman dependencies
    dependencies = with pkgs.home-assistant.python.pkgs; [ 
      pyyaml 
      pysolarmanv5
    ];

    meta = with lib; {
      description = "Home Assistant integration for Solarman data loggers";
      homepage = "https://github.com/StephanJoubert/home_assistant_solarman";
      changelog = "https://github.com/StephanJoubert/home_assistant_solarman/releases/tag/${version}";
      license = licenses.asl20;
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
      default = "deye_sg04lp3";
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
                
              ];
            }
            {
              type = "entities";
              title = "Grid Status";
              show_header_toggle = false;
              entities = [
                {
                  entity = "sensor.solarman_grid_connected_status";
                  name = "Grid Connected";
                }
                {
                  entity = "sensor.solarman_total_grid_power";
                  name = "Total Power";
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
          ];
        }
      ];
    };

    # Ensure custom_components directory exists with proper permissions
    systemd.tmpfiles.rules = [
      "d ${haCfg.dataDir}/custom_components 0755 ${haCfg.user} ${haCfg.group} -"
    ];

    # Create Solarman configuration package
    systemd.services.home-assistant.preStart =
      let
        inverterYaml = pkgs.replaceVars ./inverter.yaml {
          inverterHost = cfg.host;
          inverterSerial = cfg.serialNumber;
          inverterPort = toString cfg.port;
          lookupFile = cfg.inverterModel;
          scanInterval = toString cfg.updateInterval;
        };
      in
      ''
        ln -fns ${inverterYaml} ${haCfg.dataDir}/packages/inverter.yaml
      '';
  };
}
