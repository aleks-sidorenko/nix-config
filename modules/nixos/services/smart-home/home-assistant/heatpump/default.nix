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
      temp_from = mkOption {
        type = types.int;
        description = "Lower temperature threshold in °C";
      };
      temp_to = mkOption {
        type = types.int;
        description = "Upper temperature threshold in °C";
      };
    };
  };
in
{
  options.${namespace}.services.smart-home.home-assistant.heatpump = {
    enable = mkEnableOption "Enable heatpump integration and dashboard";
    
    modes = {
      minimal = mkOption {
        type = modeType;
        default = {
          temp_from = 15;
          temp_to = 18;
        };
        description = "Minimal heating mode (used during morning)";
      };
      
      full = mkOption {
        type = modeType;
        default = {
          temp_from = 23;
          temp_to = 28;
        };
        description = "Full heating mode (used during night)";
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
                  entity = "sensor.heatpump_status";
                  name = "Current Status";
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
                  entity = "sensor.heatpump_last_update";
                  name = "Last Update";
                }
              ];
            }
            {
              type = "entities";
              title = "Minimal Mode (Night Off)";
              show_header_toggle = false;
              entities = [
                {
                  entity = "input_number.heatpump_minimal_temp_from";
                  name = "Temperature From";
                }
                {
                  entity = "input_number.heatpump_minimal_temp_to";
                  name = "Temperature To";
                }
              ];
              footer = {
                type = "buttons";
                entities = [
                  {
                    entity = "script.heatpump_apply_minimal_mode";
                    name = "Apply Minimal Mode";
                    icon = "mdi:thermometer-low";
                    tap_action = {
                      action = "call-service";
                      service = "script.heatpump_apply_minimal_mode";
                    };
                  }
                ];
              };
            }
            {
              type = "entities";
              title = "Full Mode (Night On)";
              show_header_toggle = false;
              entities = [
                {
                  entity = "input_number.heatpump_full_temp_from";
                  name = "Temperature From";
                }
                {
                  entity = "input_number.heatpump_full_temp_to";
                  name = "Temperature To";
                }
              ];
              footer = {
                type = "buttons";
                entities = [
                  {
                    entity = "script.heatpump_apply_full_mode";
                    name = "Apply Full Mode";
                    icon = "mdi:thermometer-high";
                    tap_action = {
                      action = "call-service";
                      service = "script.heatpump_apply_full_mode";
                    };
                  }
                ];
              };
            }
            {
              type = "markdown";
              content = ''
                ## Heatpump Schedule

                The heatpump temperatures are automatically adjusted based on:
                
                ### Night Schedule
                - **Night Schedule Off**: Uses Minimal Mode settings
                - **Night Schedule On**: Uses Full Mode settings

                ### Grid Status
                - **Grid Off-Grid**: Automatically switches to Minimal Mode to conserve power

                You can adjust the temperatures using the controls above. Changes take effect when the night schedule status or grid status changes.
              '';
            }
          ];
        }
      ];

    };

    # Generate and link heatpump package configuration with templated values
    systemd.services.home-assistant.preStart =
      let
        heatpumpYaml = pkgs.replaceVars ./heatpump.yaml {
          minimal_temp_from = toString cfg.modes.minimal.temp_from;
          minimal_temp_to = toString cfg.modes.minimal.temp_to;
          full_temp_from = toString cfg.modes.full.temp_from;
          full_temp_to = toString cfg.modes.full.temp_to;
        };
      in
      ''
        ln -fns ${heatpumpYaml} ${haCfg.dataDir}/packages/heatpump.yaml
      '';
  };
}
