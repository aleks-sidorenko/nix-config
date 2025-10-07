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

in
{
  options.${namespace}.services.smart-home.zigbee2mqtt = {
    enable = mkEnableOption "Enable Zigbee2MQTT";

    package = mkOpt types.package pkgs.zigbee2mqtt_2 "Zigbee2MQTT package to use";

    user = mkOpt types.str "zigbee2mqtt" "User to run Zigbee2MQTT as";

    group = mkOpt types.str config.${namespace}.services.smart-home.group "Group to run Zigbee2MQTT as";

    device = mkOpt types.str "/dev/zigbee" "Serial device path for Zigbee coordinator";

    adapter = mkOpt types.str "auto" "Adapter type for Zigbee coordinator";

    dataDir = mkOpt types.str "/var/lib/zigbee2mqtt" "Directory where Zigbee2MQTT stores its data";

    webPort =
      mkOpt types.port defaults.network.ports.zigbee2mqtt.web
        "Port for the Zigbee2MQTT web interface";

    mqtt = {
      server =
        mkOpt types.str "mqtt://127.0.0.1:${toString defaults.network.ports.mqtt.broker}"
          "MQTT server URL";

      baseTopic = mkOpt types.str "zigbee2mqtt" "Base topic for Zigbee2MQTT MQTT messages";
    };

    permitJoin = mkBoolOpt false "Allow new devices to join (set to true temporarily when pairing)";

    logLevel = mkOpt (types.enum [
      "debug"
      "info"
      "warn"
      "error"
    ]) "info" "Log level for Zigbee2MQTT";

    homeAssistantIntegration = mkBoolOpt true "Enable Home Assistant integration";

    advanced = {
      panId = mkOpt (types.either types.int (
        types.enum [ "GENERATE" ]
      )) 52843 "PAN ID for the Zigbee network (use adapter's existing value or GENERATE)";

      channel = mkOpt types.int 11 "Zigbee channel (11-26, avoid WiFi interference)";
    };
  };

  config = mkIf cfg.enable {

    ${namespace}.services = {
      # Enable Mosquitto if not already enabled
      smart-home.mosquitto.enable = mkDefault true;
      # Configure nginx virtual host
      networking.nginx = {
        virtualHosts.zigbee2mqtt = {
          serverName = hosts.local "zigbee2mqtt";
          port = cfg.webPort;
        };
      };
    };

    # Add Zigbee2MQTT to system packages
    environment.systemPackages = with pkgs; [
      zigbee2mqtt
    ];

    # Zigbee2MQTT service
    services.zigbee2mqtt = {
      enable = true;
      package = cfg.package;
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
          adapter = cfg.adapter;
        };

        # Frontend settings
        frontend = {
          port = cfg.webPort;
          host = "0.0.0.0";
        };

        # Home Assistant integration
        homeassistant.enabled = cfg.homeAssistantIntegration;

        # Allow new devices to join
        permit_join = cfg.permitJoin;

        # Advanced settings
        advanced = {
          log_level = cfg.logLevel;
          pan_id = cfg.advanced.panId;
          network_key = "!secret network_key";
          channel = cfg.advanced.channel;

          # Adapter configuration
          adapter_concurrent = null;

          # Transmit power in dBm (default: 5)
          transmit_power = 5;

          # Enable availability for all devices
          availability_blocklist = [ ];
          availability_passlist = [ ];
          homeassistant_legacy_entity_attributes = false;
          homeassistant_legacy_triggers = false;
          legacy_api = false;
          legacy_availability_payload = false;
        };

        # Device options
        device_options = {
          legacy = false;
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

    # Configure SOPS secret for network key
    sops.secrets."service-zigbee2mqtt-network-key" = {
      sopsFile = ../../../secrets.yaml;
      owner = cfg.user;
      group = cfg.group;
      mode = "0440";
      restartUnits = [ "zigbee2mqtt.service" ];
    };

    # Ensure data directory exists with correct permissions
    # Create empty YAML files for secrets.yaml if it doesn't exist
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
      "f ${cfg.dataDir}/secrets.yaml 0644 ${cfg.user} ${cfg.group} - {}"
    ];

    # Configure zigbee2mqtt to run as the specified user/group
    systemd.services.zigbee2mqtt = {
      after = [ "mosquitto.service" ];
      wants = [ "mosquitto.service" ];

      preStart = ''
        # Create secrets.yaml file that Zigbee2MQTT can reference
        # Read the network key from sops and write to secrets.yaml
        echo "network_key: $(cat ${
          config.sops.secrets."service-zigbee2mqtt-network-key".path
        })" > "${cfg.dataDir}/secrets.yaml"
      '';

      serviceConfig = {
        User = mkForce cfg.user;
        Group = mkForce cfg.group;
        # Grant access to serial devices
        SupplementaryGroups = [ "dialout" ];
      };
    };
  };
}
