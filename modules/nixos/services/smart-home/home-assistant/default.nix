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

    config = {
      bindAddress = mkOption {
        type = types.str;
        default = "0.0.0.0";
        description = "Bind address for Home Assistant web interface";
      };

      latitude = mkOption {
        type = types.str;
        default = defaults.locale.latitude;
        description = "Latitude for Home Assistant location";
      };

      longitude = mkOption {
        type = types.str;
        default = defaults.locale.longitude;
        description = "Longitude for Home Assistant location";
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
    
    
    ${namespace}.services = {
      networking.nginx = {        
        virtualHosts.home-assistant = {
          serverName = hosts.local "home-assistant";
          port = cfg.webPort;
        };
      };
      
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

    # Home Assistant service
    services.home-assistant = {
      enable = true;
      package = cfg.package;      
      configDir = cfg.dataDir;
      configWritable = false;
      customComponents = [ ];
      customLovelaceModules = [ ];

      extraComponents = [
        # Core integrations
        "default_config"
        "met"
        "radio_browser"

        # MQTT and Zigbee
        "mqtt"
        "zha" # not used, but causes error if missing
        "esphome"

        # TV integrations
        "androidtv_remote"      
        "cast"
        

        # Useful integrations        
        "google_translate"
        "mobile_app"
        "sun"
        "history"
        "logbook"
        "recorder"
      ];

      config = {
        homeassistant = {
          name = "Home";
          latitude = cfg.config.latitude;
          longitude = cfg.config.longitude;
          time_zone = cfg.config.timeZone;
          unit_system = cfg.config.unitSystem;
          temperature_unit = "C";
          external_url = "http://${hosts.local "home-assistant"}";
          internal_url = "http://${cfg.config.bindAddress}:${toString cfg.webPort}";
          packages = "!include_dir_named ${./packages}";
        };

        # Enable the frontend
        frontend = { };

        # Enable configuration UI
        config = { };

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

      lovelaceConfig = { };
      openFirewall = true;
    };

    # Ensure data directory exists with correct permissions
    # Create empty YAML files for automations, scripts, and scenes if they don't exist
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
      "f ${cfg.dataDir}/automations.yaml 0644 ${cfg.user} ${cfg.group} - []"
      "f ${cfg.dataDir}/scripts.yaml 0644 ${cfg.user} ${cfg.group} - {}"
      "f ${cfg.dataDir}/scenes.yaml 0644 ${cfg.user} ${cfg.group} - []"
    ];

    # Ensure Home Assistant starts after MQTT if enabled
    systemd.services.home-assistant = mkIf cfg.mqtt.enable {
      after = [ "mosquitto.service" ];
      wants = [ "mosquitto.service" ];
      serviceConfig = {
        User = mkForce cfg.user;
        Group = mkForce cfg.group;
      };
    };

    # Add packages to system
    environment.systemPackages = with pkgs; [
      cfg.package
    ];

  };
}