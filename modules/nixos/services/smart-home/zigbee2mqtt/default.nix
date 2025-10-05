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
  cfg = config.${namespace}.services.smart-home.zigbee2mqtt;
  mqttCfg = config.${namespace}.services.smart-home.mosquitto;

in
{
  options.${namespace}.services.smart-home.zigbee2mqtt = {
    enable = mkEnableOption "Enable Zigbee2MQTT";

    user = mkOpt types.str "zigbee2mqtt" "User to run Zigbee2MQTT as";

    group =
      mkOpt types.str config.${namespace}.services.smart-home.group
        "Group to run Zigbee2MQTT as";

    device =
      mkOpt types.str "/dev/serial/by-id/usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus-if00-port0"
        "Serial device path for Zigbee coordinator";

    dataDir = mkOpt types.str "/var/lib/zigbee2mqtt" "Directory where Zigbee2MQTT stores its data";

    webPort =
      mkOpt types.port defaults.network.ports.zigbee2mqtt.web
        "Port for the Zigbee2MQTT web interface";

    mqtt = {
      server = mkOpt types.str "mqtt://127.0.0.1:${toString defaults.network.ports.mqtt.broker}" 
        "MQTT server URL";

      baseTopic = mkOpt types.str "zigbee2mqtt" "Base topic for Zigbee2MQTT MQTT messages";
    };

    permitJoin = mkBoolOpt false "Allow new devices to join (set to true temporarily when pairing)";

    logLevel = mkOpt (types.enum [ "debug" "info" "warn" "error" ]) "info" "Log level for Zigbee2MQTT";

    homeAssistantIntegration = mkBoolOpt true "Enable Home Assistant integration";
  };

  config = mkIf cfg.enable {
    # Enable Mosquitto if not already enabled
    ${namespace}.services.smart-home.mosquitto.enable = mkDefault true;

    # Ensure data directory exists with correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
    ];

    # Add Zigbee2MQTT to system packages
    environment.systemPackages = with pkgs; [
      zigbee2mqtt
    ];

    # Configure nginx virtual host
    ${namespace}.services.networking.nginx = {
      virtualHosts.zigbee2mqtt = {
        serverName = hosts.local "zigbee2mqtt";
        port = cfg.webPort;
      };
    };

    # Zigbee2MQTT service
    services.zigbee2mqtt = {
      enable = true;
      dataDir = cfg.dataDir;

      settings = {
        # MQTT settings
        mqtt = {
          base_topic = cfg.mqtt.baseTopic;
          server = cfg.mqtt.server;
          include_device_information = true;
        };

        # Serial settings for Zigbee coordinator
        serial = {
          port = cfg.device;
          adapter = "auto"; # Auto-detect adapter type
        };

        # Frontend settings
        frontend = {
          port = cfg.webPort;
          host = "0.0.0.0";
        };

        # Home Assistant integration
        homeassistant = cfg.homeAssistantIntegration;

        # Allow new devices to join
        permit_join = cfg.permitJoin;

        # Advanced settings
        advanced = {
          log_level = cfg.logLevel;
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
    services.udev.extraRules = ''
      # Sonoff Zigbee 3.0 USB Dongle Plus
      SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="55d4", MODE="0660", GROUP="dialout", SYMLINK+="zigbee"

      # ConBee II
      SUBSYSTEM=="tty", ATTRS{idVendor}=="1cf1", ATTRS{idProduct}=="0030", MODE="0660", GROUP="dialout", SYMLINK+="conbee2"

      # Generic USB-to-Serial adapters
      KERNEL=="ttyUSB*", MODE="0660", GROUP="dialout"
      KERNEL=="ttyACM*", MODE="0660", GROUP="dialout"
    '';

    # Configure zigbee2mqtt to run as the specified user/group
    systemd.services.zigbee2mqtt = {
      after = [ "mosquitto.service" ];
      wants = [ "mosquitto.service" ];

      serviceConfig = {
        User = mkForce cfg.user;
        Group = mkForce cfg.group;
        # Grant access to serial devices
        SupplementaryGroups = [ "dialout" ];
      };
    };
  };
}
