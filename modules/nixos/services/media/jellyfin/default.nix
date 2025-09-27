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
  cfg = config.${namespace}.services.media.jellyfin;
in
{
  options.${namespace}.services.media.jellyfin = {
    enable = mkEnableOption "Enable Jellyfin media server";

    user = mkOpt types.str "jellyfin" "User to run Jellyfin as";

    group = mkOpt types.str config.${namespace}.services.media.group "Group to run Jellyfin as";

    dataDir = mkOpt types.str "/var/lib/jellyfin" "Directory where Jellyfin stores its data";

    configDir = mkOpt types.str "/etc/jellyfin" "Directory where Jellyfin stores its configuration";

    cacheDir = mkOpt types.str "/var/cache/jellyfin" "Directory where Jellyfin stores its cache";

    logDir = mkOpt types.str "/var/log/jellyfin" "Directory where Jellyfin stores its logs";

    mediaDir = mkOpt types.str "/data/media" "Directory where media files are stored";

    package = mkOpt types.package pkgs.jellyfin "Jellyfin package to use";

    webPort = mkOpt types.port 8096 "Port for the Jellyfin web interface";

    discoveryPort =
      mkOpt types.port defaults.network.ports.jellyfin.discovery
        "Port for Jellyfin discovery";
  };

  config = mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = mkForce cfg.group;
      extraGroups = [
        "users"
        "video"
        "render"
      ];
      home = cfg.dataDir;
      createHome = true;
      description = "Jellyfin media server user";
    };

    systemd.services.jellyfin = {
      description = "Jellyfin Media Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "exec";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${cfg.package}/bin/jellyfin --datadir ${cfg.dataDir} --configdir ${cfg.configDir} --cachedir ${cfg.cacheDir} --logdir ${cfg.logDir}";
        Restart = "on-failure";
        RestartSec = "5s";
        TimeoutSec = "15s";

        # Security settings
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [
          cfg.dataDir
          cfg.configDir
          cfg.cacheDir
          cfg.logDir
          cfg.mediaDir
        ];

        # Network restrictions
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];

        # Device access for hardware transcoding
        DeviceAllow = [
          "/dev/dri/renderD128"
          "/dev/dri/card0"
        ];
        SupplementaryGroups = [
          "video"
          "render"
        ];

        # Capabilities
        LockPersonality = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
      };

      environment = {
        JELLYFIN_DATA_DIR = cfg.dataDir;
        JELLYFIN_CONFIG_DIR = cfg.configDir;
        JELLYFIN_CACHE_DIR = cfg.cacheDir;
        JELLYFIN_LOG_DIR = cfg.logDir;
      };
    };

    # Open firewall port
    networking.firewall = {
      allowedTCPPorts = [ cfg.webPort ];
      allowedUDPPorts = [
        cfg.discoveryPort
      ]; # DLNA discovery and local network discovery
    };

    # Ensure directories exist and have correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.configDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.cacheDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.logDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.mediaDir} 0755 ${cfg.user} ${cfg.group} -"
    ];

    # Add Jellyfin package to system packages
    environment.systemPackages = [ cfg.package ];

  };
}
