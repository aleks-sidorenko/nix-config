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
  
  # Generate automation for firing night_on event
  mkNightOnAutomation = ''
    - id: night_schedule_on
      alias: "Night Schedule: ON"
      description: "Fire night_on event at ${cfg.nightOnTime}"
      trigger:
        - platform: time
          at: "${cfg.nightOnTime}:00"
      action:
        - event: night_on
          event_data:
            time: "${cfg.nightOnTime}"
            source: night_schedule
            timestamp: "{{ now().isoformat() }}"
        - service: logbook.log
          data:
            name: Night Schedule
            message: "Night mode activated (night_on event fired at ${cfg.nightOnTime})"
      mode: single
  '';
  
  # Generate automation for firing night_off event
  mkNightOffAutomation = ''
    - id: night_schedule_off
      alias: "Night Schedule: OFF"
      description: "Fire night_off event at ${cfg.nightOffTime}"
      trigger:
        - platform: time
          at: "${cfg.nightOffTime}:00"
      action:
        - event: night_off
          event_data:
            time: "${cfg.nightOffTime}"
            source: night_schedule
            timestamp: "{{ now().isoformat() }}"
        - service: logbook.log
          data:
            name: Night Schedule
            message: "Day mode activated (night_off event fired at ${cfg.nightOffTime})"
      mode: single
  '';
  
in
{
  options.${namespace}.services.smart-home.home-assistant.night-schedule = {
    enable = mkEnableOption "Enable night schedule custom events (night_on and night_off)";
    
    nightOnTime = mkOption {
      type = types.str;
      default = "23:00";
      description = "Time when night_on event is fired (HH:MM format, 24-hour)";
      example = "23:00";
    };
    
    nightOffTime = mkOption {
      type = types.str;
      default = "07:00";
      description = "Time when night_off event is fired (HH:MM format, 24-hour)";
      example = "07:00";
    };
  };

  config = mkIf (haCfg.enable && cfg.enable) {
    # Generate and link night schedule automation configuration
    systemd.services.home-assistant.preStart =
      let
        nightScheduleYaml = pkgs.writeText "night-schedule.yaml" ''
          # Night Schedule Custom Events
          # Fires night_on and night_off events that other automations can listen to
          
          automation:
          ${mkNightOnAutomation}
          ${mkNightOffAutomation}
        '';
      in
      ''
        ln -fns ${nightScheduleYaml} ${haCfg.dataDir}/packages/night-schedule.yaml
      '';
  };
}

