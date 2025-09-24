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
  cfg = config.${namespace}.services.media.sonarr;
in
{
  options.${namespace}.services.media.sonarr = {
    enable = mkEnableOption "Enable Sonarr TV series management";

    user = mkOpt types.str "sonarr" "User to run Sonarr as";

    group = mkOpt types.str config.${namespace}.services.media.group "Group to run Sonarr as";

    dataDir = mkOpt types.str "/var/lib/sonarr" "Directory where Sonarr stores its data";

    downloadDir = mkOpt types.str "/data/torrents/Series" "Directory where downloads are stored";

    mediaDir = mkOpt types.str "/data/media/Series" "Directory where TV series files are stored";

    package = mkOpt types.package pkgs.sonarr "Sonarr package to use";

    webPort = mkOpt types.port defaults.network.ports.sonarr.web "Port for the Sonarr web interface";
  };

  config = mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = mkForce cfg.group;
      extraGroups = [ "users" ];
      home = cfg.dataDir;
      createHome = true;
      description = "Sonarr TV series management user";
    };

    # Ensure qbittorrent user can access sonarr downloads
    users.users.${config.${namespace}.services.media.qbittorrent.user} =
      mkIf config.${namespace}.services.media.qbittorrent.enable
        {
          extraGroups = [ cfg.group ];
        };

    systemd.services.sonarr = {
      description = "Sonarr TV series management";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${cfg.package}/bin/Sonarr -nobrowser -data=${cfg.dataDir}";
        Restart = "on-failure";
        RestartSec = "5s";

        # Security settings
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [
          cfg.dataDir
          cfg.downloadDir
          cfg.mediaDir
        ];

        # Network restrictions - Allow common address families
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
          "AF_NETLINK"
        ];

        # Capabilities - Allow basic network capabilities
        CapabilityBoundingSet = [
          "CAP_NET_BIND_SERVICE"
        ];
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "@network-io"
          "~@privileged"
        ];
      };

      environment = {
        # Ensure Sonarr can access required directories
        SONARR_DATA_DIR = cfg.dataDir;
      };
    };

    networking.firewall = {
      allowedTCPPorts = [ cfg.webPort ];
    };

    # Ensure directories exist and have correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.downloadDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.mediaDir} 0755 ${cfg.user} ${cfg.group} -"
    ];

    # Add Sonarr package to system packages
    environment.systemPackages = [ cfg.package ];

    # Persistence for important directories
    environment.persistence.${persistence.root config}.directories = [
      cfg.dataDir
      cfg.downloadDir
      cfg.mediaDir
    ];
  };
}
