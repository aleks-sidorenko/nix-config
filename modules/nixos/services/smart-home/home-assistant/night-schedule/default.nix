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
  cfg = haCfg.night-schedule;
in
{
  options.${namespace}.services.smart-home.home-assistant.night-schedule = {
    enable = mkEnableOption "Enable night schedule sensor (sensor.night_schedule)";

    nightOnTime = mkOption {
      type = types.str;
      default = "23:00";
      description = "Time when night mode starts (HH:MM format, 24-hour)";
      example = "23:00";
    };

    nightOffTime = mkOption {
      type = types.str;
      default = "07:00";
      description = "Time when night mode ends (HH:MM format, 24-hour)";
      example = "07:00";
    };
  };

  config = mkIf (haCfg.enable && cfg.enable) {
    # Generate and link night schedule automation configuration with templated values
    systemd.services.home-assistant.preStart = lib.mkAfter (
      let
        nightScheduleYaml = pkgs.replaceVars ./night_schedule.yaml {
          nightOnTime = cfg.nightOnTime;
          nightOffTime = cfg.nightOffTime;
        };
      in
      ''
        ln -fns ${nightScheduleYaml} ${haCfg.dataDir}/packages/night_schedule.yaml
      ''
    );
  };
}
