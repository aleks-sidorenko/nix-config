{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services.smart-home.home-assistant;
  userName = lib.${namespace}.userName config;

  lovelaceConfig = import ./lovelace.nix { inherit cfg; };
in
{
  options.${namespace}.services.smart-home.home-assistant = {
    enable = mkEnableOption "Enable Home Assistant";

    user = mkOpt types.str "hass" "User to run Home Assistant as";

    group =
      mkOpt types.str config.${namespace}.services.smart-home.group
        "Group to run Home Assistant as";

    dataDir = mkOpt types.str "/var/lib/hass" "Directory where Home Assistant stores its data";

    webPort =
      mkOpt types.port defaults.network.ports.home-assistant.web
        "Port for the Home Assistant web interface";

    package = mkOpt types.package pkgs.home-assistant "Home Assistant package to use";

    mosquitto = {
      enable = mkBoolOpt config.services.mosquitto.enable "Enable Home Assistant integration with Mosquitto";
    };

    extraComponents = mkOpt (types.listOf types.str) [ ] "Extra Home Assistant components to enable";

    views = mkOpt (types.listOf types.attrs) [ ] "Lovelace dashboard views";

    secrets =
      mkOpt (types.attrsOf types.path) { }
        "Secrets to be written to secrets.yaml (name -> sops secret path)";

    config = {
      bindAddress = mkOption {
        type = types.str;
        default = "0.0.0.0";
        description = "Bind address for Home Assistant web interface";
      };

      timeZone = mkOption {
        type = types.str;
        default = defaults.locale.timeZone;
        description = "Time zone for Home Assistant";
      };

      unitSystem = mkOption {
        type = types.enum [
          "metric"
          "imperial"
        ];
        default = "metric";
        description = "Unit system for Home Assistant";
      };
    };

  };

  config = mkIf cfg.enable {

    # Configure SOPS secret for latitude and longitude
    sops.secrets."service-home-assistant-latitude" = {
      sopsFile = ../../../secrets.yaml;
      owner = cfg.user;
      group = cfg.group;
      mode = "0440";
      restartUnits = [ "home-assistant.service" ];
    };

    sops.secrets."service-home-assistant-longitude" = {
      sopsFile = ../../../secrets.yaml;
      owner = cfg.user;
      group = cfg.group;
      mode = "0440";
      restartUnits = [ "home-assistant.service" ];
    };

    # Create the Home Assistant user
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = mkForce cfg.group;
      extraGroups = [
        "users"
        "dialout" # Access to serial devices
        "tty" # Access to TTY devices
      ];
      home = cfg.dataDir;
      createHome = true;
      description = "Home Assistant user";
    };

    # Set default components in namespace
    ${namespace}.services = {
      networking.nginx = {
        virtualHosts.home-assistant = {
          serverName = hosts.local "home-assistant";
          port = cfg.webPort;
        };
      };

      smart-home.home-assistant = {
        # Register base secrets
        secrets = {
          latitude = config.sops.secrets."service-home-assistant-latitude".path;
          longitude = config.sops.secrets."service-home-assistant-longitude".path;
        };

        extraComponents = [
          "default_config"
          "device_tracker"
          "esphome"
          "google_translate"
          "history"
          "isal"
          "logbook"
          "mobile_app"

          "person"
          "radio_browser"
          "recorder"
          "zone"
          "sun" # for sun.sun entity
          "time_date" # for sensor.time and sensor.date entities
        ];

      };
    };

    # Home Assistant service
    services.home-assistant = {
      enable = true;
      package = cfg.package;
      configDir = cfg.dataDir;
      configWritable = false;
      customComponents = [ ];
      customLovelaceModules = [ ];
      lovelaceConfig = lovelaceConfig;
      lovelaceConfigWritable = false;

      extraComponents = cfg.extraComponents;

      config = {
        homeassistant = {
          name = "Home";
          latitude = "!secret latitude";
          longitude = "!secret longitude";
          # elevation = "!secret elevation";
          time_zone = cfg.config.timeZone;
          unit_system = cfg.config.unitSystem;
          temperature_unit = "C";
          external_url = "http://${hosts.local "home-assistant"}";
          internal_url = "http://${cfg.config.bindAddress}:${toString cfg.webPort}";
          packages = "!include_dir_named packages";
        };

        # Enable default config
        default_config = { };

        # Enable the frontend
        frontend = { };
        # Enable configuration UI
        config = { };

        lovelace.mode = "yaml"; # use yaml mode for lovelace config

        # HTTP configuration
        http = {
          server_host = cfg.config.bindAddress;
          server_port = cfg.webPort;
          trusted_proxies = [
            "127.0.0.1"
            "::1"
            "10.0.0.0/24"
          ];
          use_x_forwarded_for = true;
          ip_ban_enabled = false;
          cors_allowed_origins = [
            "http://${hosts.local "home-assistant"}"
          ];
        };

        # Enable automation
        automation = "!include automations.yaml";
        script = "!include scripts.yaml";
        scene = "!include scenes.yaml";
      };

      extraArgs = [ ];

      # Custom configuration files
      extraPackages =
        python3Packages: with python3Packages; [
          # Additional Python packages for Home Assistant
          psycopg2
          gtts
        ];

      openFirewall = true;
    };

    # Ensure data directory exists with correct permissions
    # Create empty YAML files for automations, scripts, scenes, and secrets if they don't exist
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/packages 0755 ${cfg.user} ${cfg.group} -"
      "f ${cfg.dataDir}/automations.yaml 0644 ${cfg.user} ${cfg.group} - []"
      "f ${cfg.dataDir}/scripts.yaml 0644 ${cfg.user} ${cfg.group} - {}"
      "f ${cfg.dataDir}/scenes.yaml 0644 ${cfg.user} ${cfg.group} - []"
      "f ${cfg.dataDir}/secrets.yaml 0644 ${cfg.user} ${cfg.group} - {}"
    ];

    systemd.services.home-assistant = {
      preStart =
        let
          # Generate secret write commands from the secrets attribute set
          secretCommands = lib.concatStringsSep "\n" (
            lib.mapAttrsToList (
              name: secretPath: ''echo "${name}: $(cat ${secretPath})" >> "${cfg.dataDir}/secrets.yaml"''
            ) cfg.secrets
          );
        in
        ''
          # Create secrets.yaml file that Home Assistant can reference
          # Clear existing file and write all secrets
          : > "${cfg.dataDir}/secrets.yaml"
          ${secretCommands}
        '';

      serviceConfig = {
        User = mkForce cfg.user;
        Group = mkForce cfg.group;
      };
    }
    // mkIf cfg.mosquitto.enable {
      after = [ "mosquitto.service" ];
      wants = [ "mosquitto.service" ];
    };

    # Add packages to system
    environment.systemPackages = with pkgs; [
      cfg.package
    ];

  };
}
