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
  cfg = config.${namespace}.services.media.radarr;
in
{
  options.${namespace}.services.media.radarr = {
    enable = mkEnableOption "Enable Radarr movie management";

    user = mkOpt types.str "radarr" "User to run Radarr as";

    group = mkOpt types.str config.${namespace}.services.media.group "Group to run Radarr as";

    dataDir = mkOpt types.str "/var/lib/radarr" "Directory where Radarr stores its data";

    downloadDir = mkOpt types.str "/data/torrents" "Directory where downloads are stored";

    mediaDir = mkOpt types.str "/data/media/movies" "Directory where movie files are stored";

    package = mkOpt types.package pkgs.radarr "Radarr package to use";

    webPort = mkOpt types.port defaults.ports.radarr.web "Port for the Radarr web interface";

    openFirewall = mkBoolOpt false "Open firewall for Radarr port";
  };

  config = mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = mkForce cfg.group;
      extraGroups = [ "users" ];
      home = cfg.dataDir;
      createHome = true;
      description = "Radarr movie management user";
    };

    # Ensure qbittorrent user can access radarr downloads
    users.users.${config.${namespace}.services.media.qbittorrent.user} =
      mkIf config.${namespace}.services.media.qbittorrent.enable
        {
          extraGroups = [ cfg.group ];
        };

    systemd.services.radarr = {
      description = "Radarr movie management";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${cfg.package}/bin/Radarr -nobrowser -data=${cfg.dataDir}";
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

        # Network restrictions
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];

        # Capabilities
        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
        ];
      };

      environment = {
        # Ensure Radarr can access required directories
        RADARR_DATA_DIR = cfg.dataDir;
      };
    };

    # Open firewall port if requested
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.webPort ];
    };

    # Ensure directories exist and have correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.downloadDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.mediaDir} 0755 ${cfg.user} ${cfg.group} -"
    ];

    # Add Radarr package to system packages
    environment.systemPackages = [ cfg.package ];

    # Persistence for important directories
    environment.persistence.${persistence.root config}.directories = [
      cfg.dataDir
      cfg.downloadDir
      cfg.mediaDir
    ];
  };
}
