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
  
  # Use provided passwordFile or default to SOPS secret path
  passwordFilePath = 
    if cfg.auth.passwordFile != null 
    then cfg.auth.passwordFile 
    else config.sops.secrets."service-restic-password".path;
in
{
  options.${namespace}.services.backup.restic-server = {
    enable = mkEnableOption "Enable Restic REST server for backups";

    package = mkOpt types.package pkgs.restic-rest-server "Restic REST server package to use";

    user = mkOpt types.str "restic" "User to run Restic server as";

    group = mkOpt types.str config.${namespace}.services.backup.group "Group to run Restic server as";

    dataDir = mkOpt types.str "/var/lib/restic" "Data directory for Restic server";

    backupDir =
      mkOpt types.str "/backup"
        "Directory where backups are stored (e.g., USB disk mount point)";

    webPort = mkOpt types.port defaults.network.ports.restic.web "Port to listen on";

    listenAddress =
      mkOpt types.str "0.0.0.0:${toString cfg.webPort}"
        "Address and port to listen on for the web interface";

    appendOnly = mkBoolOpt false "Enable append-only mode (prevents deletion of data)";

    privateRepos = mkBoolOpt true "Enable private repositories (each client gets its own subdirectory)";

    prometheus = mkBoolOpt false "Enable Prometheus metrics";

    auth = {
      enable = mkBoolOpt false "Enable HTTP authentication";

      username = mkOpt types.str "restic" "Username for HTTP authentication";

      passwordFile =
        mkOpt (types.nullOr types.str) null
          "Path to file containing the password. Defaults to SOPS secret 'service-restic-password' if not specified.";
    };

    htpasswdFile =
      mkOpt types.str "${cfg.dataDir}/.htpasswd"
        "Path to htpasswd file for HTTP authentication";

    extraFlags = mkOpt (types.listOf types.str) [ ] "Extra command-line flags for rest-server";

  };

  config = mkIf cfg.enable {
    # Add Restic REST server package to system packages
    environment.systemPackages = [ cfg.package ];

    # SOPS secret for restic-server password
    sops.secrets."service-restic-password" = mkIf cfg.auth.enable {
      sopsFile = ../../../secrets.yaml;
      owner = cfg.user;
      group = cfg.group;
      mode = "0400";
    };

    # Create restic user and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
      description = "Restic server backup user";
    };

    users.groups.${cfg.group} = mkDefault { };

    # Ensure directories exist with correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.backupDir} 0755 ${cfg.user} ${cfg.group} -"
    ];

    # Restic REST server systemd service
    systemd.services.restic-rest-server = {
      description = "Restic REST Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart = mkIf cfg.auth.enable ''
        # Generate htpasswd file from SOPS secret
        if [ -f "${passwordFilePath}" ]; then
          echo "Generating htpasswd file..."
          ${pkgs.apacheHttpd}/bin/htpasswd -cbB "${cfg.htpasswdFile}" "${cfg.auth.username}" "$(cat ${passwordFilePath})"
          chmod 640 "${cfg.htpasswdFile}"
          chown ${cfg.user}:${cfg.group} "${cfg.htpasswdFile}"
          echo "htpasswd file generated successfully"
        else
          echo "Warning: Password file not found at ${passwordFilePath}"
        fi
      '';

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart =
          let
            flags = [
              "--path ${cfg.backupDir}"
              "--listen ${cfg.listenAddress}"
            ]
            ++ optional cfg.appendOnly "--append-only"
            ++ optional cfg.privateRepos "--private-repos"
            ++ optional cfg.prometheus "--prometheus"
            ++ (if cfg.auth.enable then [ "--htpasswd-file ${cfg.htpasswdFile}" ] else [ "--no-auth" ])
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
        ReadWritePaths = [
          cfg.dataDir
          cfg.backupDir
        ];
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        LockPersonality = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        PrivateDevices = true;
      };
    };

    # Open firewall port if needed
    networking.firewall.allowedTCPPorts = [ cfg.webPort ];

    ${namespace}.services.networking.nginx = {
      virtualHosts.restic-server = {
        serverName = hosts.local "restic";
        port = cfg.webPort;
      };
    };
  };
}
