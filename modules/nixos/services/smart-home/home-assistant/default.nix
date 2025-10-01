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
    enable = mkEnableOption "Enable Home Assistant with Zigbee support";

    user = mkOpt types.str "hass" "User to run Home Assistant as";

    group =
      mkOpt types.str config.${namespace}.services.smart-home.group
        "Group to run Home Assistant as";

    dataDir = mkOpt types.str "/var/lib/hass" "Directory where Home Assistant stores its data";

    webPort =
      mkOpt types.port defaults.network.ports.home-assistant.web
        "Port for the Home Assistant web interface";

    package = mkOpt types.package pkgs.home-assistant "Home Assistant package to use";

    zigbee = {
      enable = mkBoolOpt true "Enable Zigbee support via Zigbee2MQTT";

      device =
        mkOpt types.str "/dev/serial/by-id/usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus-if00-port0"
          "Serial device path for Zigbee coordinator";

      dataDir = mkOpt types.str "/var/lib/zigbee2mqtt" "Directory where Zigbee2MQTT stores its data";

      webPort =
        mkOpt types.port defaults.network.ports.zigbee2mqtt.web
          "Port for the Zigbee2MQTT web interface";
    };

    mqtt = {
      enable = mkBoolOpt true "Enable MQTT broker (Mosquitto)";

      dataDir = mkOpt types.str "/var/lib/mosquitto" "Directory where Mosquitto stores its data";

      port = mkOpt types.port defaults.network.ports.mqtt.broker "Port for the MQTT broker";
    };

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
    ${namespace} = {
      services.networking.nginx = {
        virtualHosts =
          {
            home-assistant = {
              serverName = hosts.local "home-assistant";
              port = cfg.webPort;
            };
          }
          // optionalAttrs cfg.zigbee.enable {
            zigbee2mqtt = {
              serverName = hosts.local "zigbee2mqtt";
              port = cfg.zigbee.webPort;
            };
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
      user = cfg.user;
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
        "zha" # Zigbee Home Automation (alternative to zigbee2mqtt)

        # Useful integrations
        "esphome"
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
          external_url = "http://${hosts.local "home-assistant"}:${toString cfg.webPort}";
          internal_url = "http://${cfg.config.bindAddress}:${toString cfg.webPort}";
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
        };

        # MQTT integration
        mqtt = mkIf cfg.mqtt.enable {
          broker = "127.0.0.1";
          port = cfg.mqtt.port;
          discovery = true;
          discovery_prefix = "homeassistant";
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
    systemd.tmpfiles.rules =
      [
        "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
      ]
      ++ optionals cfg.zigbee.enable [
        "d ${cfg.zigbee.dataDir} 0755 ${cfg.user} ${cfg.group} -"
      ]
      ++ optionals cfg.mqtt.enable [
        "d ${cfg.mqtt.dataDir} 0755 ${cfg.user} ${cfg.group} -"
      ];

    # MQTT Broker (Mosquitto)
    services.mosquitto = mkIf cfg.mqtt.enable {
      enable = true;
      dataDir = cfg.mqtt.dataDir;
      listeners = [
        {
          acl = [
            "pattern readwrite #"
          ];
          omitPasswordAuth = true;
          settings.allow_anonymous = true;
          port = cfg.mqtt.port;
          address = "127.0.0.1";
        }
      ];
    };

    # Zigbee2MQTT service
    services.zigbee2mqtt = mkIf cfg.zigbee.enable {
      enable = true;
      dataDir = cfg.zigbee.dataDir;
      openFirewall = true;

      settings = {
        # MQTT settings
        mqtt = {
          base_topic = "zigbee2mqtt";
          server = "mqtt://127.0.0.1:${toString cfg.mqtt.port}";
          include_device_information = true;
        };

        # Serial settings for Zigbee coordinator
        serial = {
          port = cfg.zigbee.device;
          adapter = "auto"; # Auto-detect adapter type
        };

        # Frontend settings
        frontend = {
          port = cfg.zigbee.webPort;
          host = "0.0.0.0";
        };

        # Home Assistant integration
        homeassistant = true;

        # Allow new devices to join
        permit_join = false; # Set to true temporarily when pairing new devices

        # Advanced settings
        advanced = {
          log_level = "info";
          pan_id = "GENERATE";
          network_key = "GENERATE";
          channel = 11;

          # Enable availability for all devices
          availability_blocklist = [ ];
          availability_passlist = [ ];
        };

        # Device options
        device_options = {
          retain = true;
        };
      };
    };

    # Grant access to serial devices for Zigbee
    services.udev.extraRules = mkIf cfg.zigbee.enable ''
      # Sonoff Zigbee 3.0 USB Dongle Plus
      SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="55d4", MODE="0660", GROUP="dialout", SYMLINK+="zigbee"

      # ConBee II
      SUBSYSTEM=="tty", ATTRS{idVendor}=="1cf1", ATTRS{idProduct}=="0030", MODE="0660", GROUP="dialout", SYMLINK+="conbee2"

      # Generic USB-to-Serial adapters
      KERNEL=="ttyUSB*", MODE="0660", GROUP="dialout"
      KERNEL=="ttyACM*", MODE="0660", GROUP="dialout"
    '';

    # Ensure Home Assistant user is in the dialout group
    systemd.services.home-assistant = {
      after = mkIf cfg.mqtt.enable [ "mosquitto.service" ];
      wants = mkIf cfg.mqtt.enable [ "mosquitto.service" ];
      serviceConfig = {
        Group = cfg.group;
      };
    };

    # Configure mosquitto to run as the home-assistant user/group
    systemd.services.mosquitto = mkIf cfg.mqtt.enable {
      serviceConfig = {
        User = mkForce cfg.user;
        Group = mkForce cfg.group;
      };
    };

    # Configure zigbee2mqtt to run as the home-assistant user/group
    systemd.services.zigbee2mqtt = mkIf cfg.zigbee.enable {
      after = [ "mosquitto.service" ];
      wants = [ "mosquitto.service" ];

      serviceConfig = {
        User = mkForce cfg.user;
        Group = mkForce cfg.group;
        # Grant access to serial devices
        SupplementaryGroups = [ "dialout" ];
      };
    };

    # Add packages to system
    environment.systemPackages =
      with pkgs;
      [
        cfg.package
      ]
      ++ optionals cfg.zigbee.enable [
        zigbee2mqtt
      ];

  };
}
