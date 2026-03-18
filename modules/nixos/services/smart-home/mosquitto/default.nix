{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.services.smart-home.mosquitto;

in
{
  options.${namespace}.services.smart-home.mosquitto = {
    enable = mkEnableOption "Enable Mosquitto MQTT broker";

    user = mkOpt types.str "mosquitto" "User to run Mosquitto as";

    group = mkOpt types.str config.${namespace}.services.smart-home.group "Group to run Mosquitto as";

    dataDir = mkOpt types.str "/var/lib/mosquitto" "Directory where Mosquitto stores its data";

    port = mkOpt types.port defaults.network.ports.mqtt.broker "Port for the MQTT broker";

    bindAddress = mkOpt types.str "127.0.0.1" "Bind address for MQTT broker";

    allowAnonymous = mkBoolOpt true "Allow anonymous MQTT connections";
  };

  config = mkIf cfg.enable {
    # Ensure data directory exists with correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
    ];

    # MQTT Broker (Mosquitto)
    services.mosquitto = {
      enable = true;
      inherit (cfg) dataDir;
      listeners = [
        {
          acl = [
            "pattern readwrite #"
          ];
          omitPasswordAuth = true;
          settings.allow_anonymous = cfg.allowAnonymous;
          inherit (cfg) port;
          address = cfg.bindAddress;
        }
      ];
    };

    # Configure mosquitto to run as the specified user/group
    systemd.services.mosquitto = {
      serviceConfig = {
        User = mkForce cfg.user;
        Group = mkForce cfg.group;
      };
    };
  };
}
