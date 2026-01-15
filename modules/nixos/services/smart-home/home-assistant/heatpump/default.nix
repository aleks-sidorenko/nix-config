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

    modes = {
      off = mkOption {
        type = modeType;
        default = {
          temperature_from = 15;
          temperature_to = 18;
        };
        description = "Off heating mode (used during morning)";
      };

      on = mkOption {
        type = modeType;
        default = {
          temperature_from = 23;
          temperature_to = 28;
        };
        description = "On heating mode (used during night)";
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
                  entity = "sensor.heatpump_last_update";
                  name = "Last Update";
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
                ## Heatpump Schedule

                The heatpump temperatures are automatically adjusted based on:

                ### Night Schedule
                - **Night Schedule Off**: Uses Off Mode settings (configured in Nix)
                - **Night Schedule On**: Uses On Mode settings (adjustable above)

                ### Grid Status
                - **Grid Off**: Automatically switches to Off Mode to conserve power
                - **Grid On**: Automatically switches to On Mode to heat the house if Night Schedule is On

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
        };
      in
      ''
        ln -fns ${heatpumpYaml} ${haCfg.dataDir}/packages/heatpump.yaml
      ''
    );
  };
}
