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
  cfg = haCfg.tv;
  
  # Validate time format HH:MM and range
  validateTime = time:
    let
      parts = lib.splitString ":" time;
      hasCorrectFormat = (builtins.length parts) == 2;
      hour = if hasCorrectFormat then lib.toInt (builtins.elemAt parts 0) else -1;
      minute = if hasCorrectFormat then lib.toInt (builtins.elemAt parts 1) else -1;
      validHour = hour >= 0 && hour <= 23;
      validMinute = minute >= 0 && minute <= 59;
    in
    hasCorrectFormat && validHour && validMinute;
  
  # Convert time HH:MM to minutes since midnight for comparison
  timeToMinutes = time:
    let
      parts = lib.splitString ":" time;
      hour = lib.toInt (builtins.elemAt parts 0);
      minute = lib.toInt (builtins.elemAt parts 1);
    in
    (hour * 60) + minute;
  
  # Define the interval submodule type
  intervalType = types.submodule ({ config, ... }: {
    options = {
      name = mkOption {
        type = types.strMatching "[a-zA-Z0-9_-]+";
        description = "Name/label for this interval (used in automation IDs and log messages)";
        example = "morning";
      };
      
      start = mkOption {
        type = types.str;
        description = "Start time in HH:MM format (24-hour)";
        example = "08:00";
      };
      
      end = mkOption {
        type = types.str;
        description = ''
          End time in HH:MM format (24-hour).
          Can be earlier than start time to indicate an overnight interval (e.g., 22:00 to 01:00).
        '';
        example = "10:00";
      };
      
      crossesMidnight = mkOption {
        type = types.bool;
        readOnly = true;
        default = (timeToMinutes config.end) < (timeToMinutes config.start);
        description = "Whether this interval crosses midnight (end time is before start time)";
      };
    };
  });
  
  # Generate automation for turning ON at interval start
  mkOnAutomation = interval:
    let
      midnightNote = if interval.crossesMidnight then " (overnight interval)" else "";
    in
    ''
      - id: tv_plug_${interval.name}_on
        alias: "TV Plug: ${interval.name} ON"
        description: "Turn TV plug ON at ${interval.start}${midnightNote}"
        trigger:
          - platform: time
            at: "${interval.start}:00"
        action:
          - service: switch.turn_on
            target:
              entity_id: ${cfg.entity_id}
          - service: logbook.log
            data:
              name: TV Plug
              message: "${interval.name} schedule: TV turned ON at ${interval.start}"
        mode: single
    '';
  
  # Generate automation for turning OFF at interval end
  mkOffAutomation = interval:
    let
      midnightNote = if interval.crossesMidnight then " (overnight interval)" else "";
    in
    ''
      - id: tv_plug_${interval.name}_off
        alias: "TV Plug: ${interval.name} OFF"
        description: "Turn TV plug OFF at ${interval.end}${midnightNote}"
        trigger:
          - platform: time
            at: "${interval.end}:00"
        action:
          - service: switch.turn_off
            target:
              entity_id: ${cfg.entity_id}
          - service: logbook.log
            data:
              name: TV Plug
              message: "${interval.name} schedule: TV turned OFF at ${interval.end}"
        mode: single
    '';
  
  # Generate both ON and OFF automations for an interval
  mkIntervalAutomations = interval: 
    (mkOnAutomation interval) + "\n" + (mkOffAutomation interval);
  
  # Generate all automations from the intervals list
  allAutomations = lib.concatMapStrings mkIntervalAutomations cfg.intervals;
  
in
{
  options.${namespace}.services.smart-home.home-assistant.tv = {
    enable = mkEnableOption "Enable TV plug automation";
    
    entity_id = mkOption {
      type = types.str;
      default = "switch.floor1_living_plug_tv";
      description = "Entity ID of the TV plug in Home Assistant";
    };
    
    intervals = mkOption {
      type = types.listOf intervalType;
      default = [
        {
          name = "morning";
          start = "08:00";
          end = "10:00";
        }
        {
          name = "evening";
          start = "17:00";
          end = "19:00";
        }
        {
          name = "night";
          start = "22:00";
          end = "01:00";
        }
      ];
      description = ''
        List of time intervals when the TV plug should be turned on.
        Supports overnight intervals where end time is before start time (e.g., 22:00 to 01:00).
      '';
      example = literalExpression ''
        [
          {
            name = "morning";
            start = "08:00";
            end = "10:00";
          }
          {
            name = "afternoon";
            start = "14:00";
            end = "16:00";
          }
          {
            name = "evening";
            start = "17:00";
            end = "22:00";
          }
          {
            name = "night";
            start = "22:00";
            end = "01:00";  # Overnight interval
          }
        ]
      '';
    };
  };

  config = mkIf (haCfg.enable && cfg.enable) {
    # Validate intervals at build time
    assertions = [
      # Validate all start times
      {
        assertion = builtins.all (interval: validateTime interval.start) cfg.intervals;
        message = ''
          TV plug automation: All start times must be in valid HH:MM format (24-hour).
          Invalid intervals found: ${
            lib.concatMapStringsSep ", " 
              (i: "${i.name}: ${i.start}") 
              (builtins.filter (i: !(validateTime i.start)) cfg.intervals)
          }
        '';
      }
      
      # Validate all end times
      {
        assertion = builtins.all (interval: validateTime interval.end) cfg.intervals;
        message = ''
          TV plug automation: All end times must be in valid HH:MM format (24-hour).
          Invalid intervals found: ${
            lib.concatMapStringsSep ", " 
              (i: "${i.name}: ${i.end}") 
              (builtins.filter (i: !(validateTime i.end)) cfg.intervals)
          }
        '';
      }
      
      # Validate unique interval names
      {
        assertion =
          let
            names = map (i: i.name) cfg.intervals;
            uniqueNames = lib.unique names;
          in
          (builtins.length names) == (builtins.length uniqueNames);
        message = ''
          TV plug automation: All interval names must be unique.
          Found duplicate names in: ${lib.concatStringsSep ", " (map (i: i.name) cfg.intervals)}
        '';
      }
    ];
    
    # Generate and link TV automation configuration
    systemd.services.home-assistant.preStart =
      let
        tvYaml = pkgs.writeText "tv.yaml" ''
          # TV Plug Automation
          # Automatically turns TV plug on during specified time windows
          
          automation:
          ${allAutomations}
        '';
      in
      ''
        ln -fns ${tvYaml} ${haCfg.dataDir}/packages/tv.yaml
      '';
  };
}
