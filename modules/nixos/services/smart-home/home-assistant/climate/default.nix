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
  cfg = haCfg.climate;
in
{
  options.${namespace}.services.smart-home.home-assistant.climate = {
    enable = mkEnableOption "Enable climate automations";

    showerFan = {
      entity_id = mkOption {
        type = types.str;
        default = "switch.floor2_shower_switch_fan";
        description = "Entity ID of the shower fan switch";
        example = "switch.floor2_shower_switch_fan";
      };

      duration_seconds = mkOption {
        type = types.int;
        default = 300;
        description = "Duration in seconds the shower fan should run after being turned on (default: 300 = 5 minutes)";
      };
    };
  };

  config = mkIf (haCfg.enable && cfg.enable) {

    # Generate and link climate package configuration with templated values
    systemd.services.home-assistant.preStart =
      let
        climateYaml = pkgs.replaceVars ./climate.yaml {
          shower_fan_entity_id = cfg.showerFan.entity_id;
          shower_fan_duration = toString cfg.showerFan.duration_seconds;
        };
      in
      ''
        ln -fns ${climateYaml} ${haCfg.dataDir}/packages/climate.yaml
      '';
  };
}
