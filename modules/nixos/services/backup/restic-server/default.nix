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
  cfg = config.${namespace}.services.backup.restic-server;
in
{
  options.${namespace}.services.backup.restic-server = {
    enable = mkEnableOption "Enable Restic REST server for backups";

    package = mkOpt types.package pkgs.restic-rest-server "Restic REST server package to use";

    user = mkOpt types.str "restic" "User to run Restic server as";

    group = mkOpt types.str "restic" "Group to run Restic server as";

    dataDir = mkOpt types.str "/backup" "Directory where backups are stored (e.g., USB disk mount point)";
    
    webPort = mkOpt types.port defaults.network.ports.restic-server.web "Port to listen on";

    listenAddress = mkOpt types.str "0.0.0.0:${toString cfg.webPort}" "Address and port to listen on for the web interface";

    appendOnly = mkBoolOpt false "Enable append-only mode (prevents deletion of data)";

    privateRepos = mkBoolOpt true "Enable private repositories (each client gets its own subdirectory)";

    prometheus = mkBoolOpt false "Enable Prometheus metrics";

    extraFlags = mkOpt (types.listOf types.str) [ ] "Extra command-line flags for rest-server";
    
  };

  config = mkIf cfg.enable {
    # Add Restic REST server package to system packages
    environment.systemPackages = [ cfg.package ];

    # Create restic user and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = false; # Don't create home, as it's the backup directory
      description = "Restic backup server user";
    };

    users.groups.${cfg.group} = { };

    # Ensure backup directory exists with correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0700 ${cfg.user} ${cfg.group} -"
    ];

    # Restic REST server systemd service
    systemd.services.restic-rest-server = {
      description = "Restic REST Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = 
          let
            flags = [
              "--path ${cfg.dataDir}"
              "--listen ${cfg.listenAddress}"
            ]
            ++ optional cfg.appendOnly "--append-only"
            ++ optional cfg.privateRepos "--private-repos"
            ++ optional cfg.prometheus "--prometheus"
            ++ cfg.extraFlags;
          in
          "${cfg.package}/bin/rest-server ${concatStringsSep " " flags}";

        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        RestrictNamespaces = true;
        LockPersonality = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        PrivateDevices = true;
      };
    };

    # Open firewall port if needed
    # Note: Users should explicitly open the port in their networking configuration
    # This is just a reminder comment
    # networking.firewall.allowedTCPPorts = [ 8000 ];
  };
}

