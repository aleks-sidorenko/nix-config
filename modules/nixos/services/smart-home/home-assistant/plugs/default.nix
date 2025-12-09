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
  cfg = haCfg.plugs;

  # Helper to remove leading zero from a numeric string (e.g., "08" -> "8", "00" -> "0")
  stripLeadingZero =
    str:
    if lib.hasPrefix "0" str && builtins.stringLength str > 1 then
      builtins.substring 1 (builtins.stringLength str - 1) str
    else
      str;

  # Parse time string "HH:MM" into { hour = int; minute = int; }
  # Removes leading zeros before converting to int
  parseTime =
    time:
    let
      parts = lib.splitString ":" time;
    in
    {
      hour = lib.toInt (stripLeadingZero (builtins.elemAt parts 0));
      minute = lib.toInt (stripLeadingZero (builtins.elemAt parts 1));
    };

  # Validate time format HH:MM and range
  validateTime =
    time:
    let
      parts = lib.splitString ":" time;
      hasCorrectFormat = (builtins.length parts) == 2;
      parsed =
        if hasCorrectFormat then
          parseTime time
        else
          {
            hour = -1;
            minute = -1;
          };
      validHour = parsed.hour >= 0 && parsed.hour <= 23;
      validMinute = parsed.minute >= 0 && parsed.minute <= 59;
    in
    hasCorrectFormat && validHour && validMinute;

  # Convert time HH:MM to minutes since midnight for comparison
  timeToMinutes =
    time:
    let
      parsed = parseTime time;
    in
    (parsed.hour * 60) + parsed.minute;

  # Define the interval submodule type
  intervalType = types.submodule (
    { config, ... }:
    {
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
    }
  );

  # Define the plug submodule type
  plugType = types.submodule (
    { config, ... }:
    {
      options = {
        enable = mkEnableOption "Enable this plug automation";

        name = mkOption {
          type = types.strMatching "[a-zA-Z0-9_-]+";
          description = "Unique name/identifier for this plug (used in automation IDs and file names)";
          example = "tv";
        };

        displayName = mkOption {
          type = types.str;
          default = config.name;
          description = "Human-readable display name for this plug (used in logs and messages)";
          example = "TV";
        };

        entity_id = mkOption {
          type = types.str;
          description = "Entity ID of the plug in Home Assistant";
          example = "switch.floor1_living_plug_tv";
        };

        intervals = mkOption {
          type = types.listOf intervalType;
          default = [ ];
          description = ''
            List of time intervals when the plug should be turned on.
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
                name = "evening";
                start = "18:00";
                end = "22:00";
              }
            ]
          '';
        };
      };
    }
  );

  # Generate automation for turning ON at interval start for a specific plug
  mkOnAutomation =
    plug: interval:
    let
      midnightNote = if interval.crossesMidnight then " (overnight interval)" else "";
    in
    ''
      - id: ${plug.name}_plug_${interval.name}_on
        alias: "${plug.displayName} Plug: ${interval.name} ON"
        description: "Turn ${plug.displayName} plug ON at ${interval.start}${midnightNote}"
        trigger:
          - platform: time
            at: "${interval.start}:00"
        action:
          - service: switch.turn_on
            target:
              entity_id: ${plug.entity_id}
          - service: logbook.log
            data:
              name: ${plug.displayName} Plug
              message: "${interval.name} schedule: ${plug.displayName} turned ON at ${interval.start}"
        mode: single
    '';

  # Generate automation for turning OFF at interval end for a specific plug
  mkOffAutomation =
    plug: interval:
    let
      midnightNote = if interval.crossesMidnight then " (overnight interval)" else "";
    in
    ''
      - id: ${plug.name}_plug_${interval.name}_off
        alias: "${plug.displayName} Plug: ${interval.name} OFF"
        description: "Turn ${plug.displayName} plug OFF at ${interval.end}${midnightNote}"
        trigger:
          - platform: time
            at: "${interval.end}:00"
        action:
          - service: switch.turn_off
            target:
              entity_id: ${plug.entity_id}
          - service: logbook.log
            data:
              name: ${plug.displayName} Plug
              message: "${interval.name} schedule: ${plug.displayName} turned OFF at ${interval.end}"
        mode: single
    '';

  # Generate both ON and OFF automations for an interval
  mkIntervalAutomations =
    plug: interval: (mkOnAutomation plug interval) + "\n" + (mkOffAutomation plug interval);

  # Generate all automations for a single plug
  mkPlugAutomations = plug: lib.concatMapStrings (mkIntervalAutomations plug) plug.intervals;

  # Get list of enabled plugs
  enabledPlugs = builtins.filter (p: p.enable) cfg.plugs;

  # Generate YAML content for a single plug
  mkPlugYaml = plug: ''
    # ${plug.displayName} Plug Automation
    # Automatically turns ${plug.displayName} plug on during specified time windows

    automation:
    ${mkPlugAutomations plug}
  '';

  # Generate assertions for a single plug
  mkPlugAssertions = plug: [
    # Validate all start times
    {
      assertion = builtins.all (interval: validateTime interval.start) plug.intervals;
      message = ''
        ${plug.displayName} plug automation: All start times must be in valid HH:MM format (24-hour).
        Invalid intervals found: ${
          lib.concatMapStringsSep ", " (i: "${i.name}: ${i.start}") (
            builtins.filter (i: !(validateTime i.start)) plug.intervals
          )
        }
      '';
    }

    # Validate all end times
    {
      assertion = builtins.all (interval: validateTime interval.end) plug.intervals;
      message = ''
        ${plug.displayName} plug automation: All end times must be in valid HH:MM format (24-hour).
        Invalid intervals found: ${
          lib.concatMapStringsSep ", " (i: "${i.name}: ${i.end}") (
            builtins.filter (i: !(validateTime i.end)) plug.intervals
          )
        }
      '';
    }

    # Validate unique interval names within plug
    {
      assertion =
        let
          names = map (i: i.name) plug.intervals;
          uniqueNames = lib.unique names;
        in
        (builtins.length names) == (builtins.length uniqueNames);
      message = ''
        ${plug.displayName} plug automation: All interval names must be unique.
        Found duplicate names in: ${lib.concatStringsSep ", " (map (i: i.name) plug.intervals)}
      '';
    }
  ];

in
{
  options.${namespace}.services.smart-home.home-assistant.plugs = {
    enable = mkEnableOption "Enable smart plug automations";

    plugs = mkOption {
      type = types.listOf plugType;
      default = [ ];
      description = ''
        List of smart plugs to manage with Home Assistant automations.
        Each plug can have its own entity ID and list of time intervals.
      '';
      example = literalExpression ''
        [
          {
            enable = true;
            name = "tv";
            displayName = "TV";
            entity_id = "switch.floor1_living_plug_tv";
            intervals = [
              { name = "morning"; start = "07:30"; end = "09:30"; }
              { name = "evening"; start = "18:00"; end = "22:00"; }
            ];
          }
          {
            enable = true;
            name = "fireplace";
            displayName = "Fireplace";
            entity_id = "switch.floor1_living_plug_fireplace";
            intervals = [
              { name = "evening"; start = "16:00"; end = "00:00"; }
            ];
          }
        ]
      '';
    };
  };

  config = mkIf (haCfg.enable && cfg.enable) {
    # Validate plug configurations at build time
    assertions =
      # Validate unique plug names
      [
        {
          assertion =
            let
              names = map (p: p.name) cfg.plugs;
              uniqueNames = lib.unique names;
            in
            (builtins.length names) == (builtins.length uniqueNames);
          message = ''
            Plug automation: All plug names must be unique.
            Found duplicate names in: ${lib.concatStringsSep ", " (map (p: p.name) cfg.plugs)}
          '';
        }
      ]
      # Add per-plug assertions
      ++ (lib.concatMap mkPlugAssertions enabledPlugs);

    # Generate and link plug automation configurations
    systemd.services.home-assistant.preStart =
      let
        # Generate a YAML file for each enabled plug
        plugYamlFiles = map (plug: {
          name = plug.name;
          yaml = pkgs.writeText "plug-${plug.name}.yaml" (mkPlugYaml plug);
        }) enabledPlugs;

        # Generate symlink commands for all enabled plugs
        symlinkCommands = lib.concatMapStrings (p: ''
          ln -fns ${p.yaml} ${haCfg.dataDir}/packages/plug-${p.name}.yaml
        '') plugYamlFiles;
      in
      symlinkCommands;
  };
}
