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
  cfg = config.${namespace}.services.media.qbittorrent;

  # Default categories for qBittorrent with subcategories
  defaultCategories = [
    "Videos"
    "Audio"
    "Books"
    "Software"
    "Other"
  ];

in
{
  options.${namespace}.services.media.qbittorrent = {
    enable = mkEnableOption "Enable qBittorrent daemon";
    homeDir = mkOpt types.str "/var/lib/qbittorrent" "Home directory for qBittorrent";
    categories = mkOption {
      type = types.listOf types.str;
      default = defaultCategories;
      example = [
        "Videos/Movies"
        "Videos/Movies/Action"
        "Videos/Series/TV Shows"
        "Audio/Music"
        "Books/Fiction"
      ];
      description = ''
        List of download categories. Supports hierarchical subcategories using forward slashes.
        Each category will have its own subdirectory structure under the downloadPath.
        Examples: "Video/Movies", "Video/Series/Anime", "Books/Fiction", etc.
      '';
    };

    user = mkOpt types.str "qbittorrent" "User to run qBittorrent as";

    group = mkOpt types.str config.${namespace}.services.media.group "Group to run qBittorrent as";

    port = mkOpt types.port 8080 "Port for the qBittorrent web interface";

    downloadPath = mkOpt types.str "/data/torrents" "Base download path for qBittorrent";

    package = mkOpt types.package pkgs.qbittorrent-nox "qBittorrent package to use";
  };

  config = mkIf cfg.enable (
    {

      users.users.${cfg.user} = {
        isSystemUser = true;
        group = mkForce cfg.group;
        extraGroups = [ "users" ];
        home = cfg.homeDir;
        createHome = true;
        description = "qBittorrent daemon user";
      };

      # Create systemd service for qBittorrent
      systemd.services.qbittorrent = {
        description = "qBittorrent daemon";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "exec";
          User = cfg.user;
          Group = cfg.group;
          ExecStart = "${cfg.package}/bin/qbittorrent-nox --webui-port=${toString cfg.port}";
          Restart = "on-failure";
          RestartSec = "5s";

          # Security settings
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [
            cfg.homeDir
            cfg.downloadPath
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

        preStart = ''
          # Ensure download directories exist with correct permissions
          ${lib.concatMapStringsSep "\n" (category: ''
            mkdir -p "${cfg.downloadPath}/${category}"
            chown ${cfg.user}:${cfg.group} "${cfg.downloadPath}/${category}"
            chmod 755 "${cfg.downloadPath}/${category}"
          '') cfg.categories}

          # Ensure config directory exists
          mkdir -p ${cfg.homeDir}/.config/qBittorrent
          chown -R ${cfg.user}:${cfg.group} ${cfg.homeDir}
        '';
      };

      # Open firewall ports
      networking.firewall = {
        allowedTCPPorts = [ cfg.port ];
      };

      # Ensure the media directories exist and have correct permissions
      systemd.tmpfiles.rules =
        [
          "d ${cfg.downloadPath} 0755 ${cfg.user} ${cfg.group} -"
        ]
        ++ map (
          category: "d ${cfg.downloadPath}/${category} 0755 ${cfg.user} ${cfg.group} -"
        ) cfg.categories;

      # Add qBittorrent package to system packages
      environment.systemPackages = [ cfg.package ];

    }
    // (persistence.persistentDirectories config [
      cfg.homeDir
      cfg.downloadPath
    ])
  );
}
