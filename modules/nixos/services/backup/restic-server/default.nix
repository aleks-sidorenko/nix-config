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

    user = mkOpt types.str "restic-server" "User to run Restic server as";

    group = mkOpt types.str config.${namespace}.services.backup.group "Group to run Restic server as";

    dataDir = mkOpt types.str "/var/lib/restic-server" "Data directory for Restic server";

    backupDir =
      mkOpt types.str "/backup"
        "Directory where backups are stored (e.g., USB disk mount point)";

    webPort = mkOpt types.port defaults.network.ports.restic.web "Port to listen on";

    # Loopback because nginx is the ingress; without htpasswdFile that is
    # also the only thing gating write access to the repository.
    listenAddress =
      mkOpt types.str "127.0.0.1:${toString cfg.webPort}"
        "Address and port to listen on for the web interface";

    htpasswdFile =
      mkOpt (types.nullOr types.path) null
        "Path to an htpasswd file (e.g. a SOPS secret). Required before the repository is published: nginx adds no authentication of its own, so a proxied --no-auth server is open to every tailnet peer.";

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
      inherit (cfg) group;
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
            ++ (if cfg.htpasswdFile != null then [ "--htpasswd-file ${cfg.htpasswdFile}" ] else [ "--no-auth" ])
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

    warnings = optional (cfg.htpasswdFile == null) ''
      services.backup.restic-server has no htpasswdFile: the repository stays
      on loopback and is not published, so remote clients cannot reach it.
    '';

    # Deliberately no firewall opening: nginx is the ingress, and opening the
    # port here would let clients bypass it. Published only once the server
    # authenticates — nginx does not, so proxying --no-auth would hand every
    # tailnet peer write and delete on the whole repository.
    ${namespace}.services.networking.nginx = mkIf (cfg.htpasswdFile != null) {
      virtualHosts.restic-server = {
        serverName = hosts.service "restic";
        port = cfg.webPort;
        clientMaxBodySize = "0"; # Unlimited - required for large backup uploads
      };
    };
  };
}
