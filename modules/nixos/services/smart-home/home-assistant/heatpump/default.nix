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
in
{
  options.${namespace}.services.smart-home.home-assistant.heatpump = {
    enable = mkEnableOption "Enable heatpump integration and dashboard";
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
              title = "Heatpump Control";
              show_header_toggle = false;
              entities = [
                {
                  entity = "sensor.heatpump_status";
                  name = "Status";
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
              type = "markdown";
              content = ''
                ## Heatpump Schedule

                **Morning (7:00):** 15°C - 18°C
                **Night (23:00):** 23°C - 28°C

                The heatpump temperatures are automatically adjusted at these times.
              '';
            }
          ];
        }
      ];

    };

    # Link heatpump package configuration
    systemd.services.home-assistant.preStart = ''
      ln -fns ${./heatpump.yaml} ${haCfg.dataDir}/packages/heatpump.yaml
    '';
  };
}
