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
  configDir = "${cfg.homeDir}/.config/qBittorrent";
  logsDir = "${cfg.homeDir}/.local/share/qBittorrent/logs";
  userName = lib.${namespace}.userName config;

  # Default categories for qBittorrent with subcategories
  defaultCategories = [
    "Videos"
    "Audio"
    "Books"
    "Software"
    "Other"
  ];

  onFinishScript = pkgs.writeShellScript "qbittorrent-on-finish" ''
    #!${pkgs.runtimeShell}
    # qBittorrent on-finish script for *arr integration
    # This script is called when a download completes
    # The *arr applications (Sonarr/Radarr) will handle the actual file moving via hardlinks

    TORRENT_PATH="$1"
    TORRENT_NAME="$2"
    TORRENT_HASH="$3"

    echo "$(date): Download completed"
    echo "  Path: $TORRENT_PATH"
    echo "  Name: $TORRENT_NAME" 
    echo "  Hash: $TORRENT_HASH"

    # Log to systemd journal for monitoring
    ${pkgs.systemd}/bin/systemd-cat -t qbittorrent echo "Download completed: $TORRENT_NAME"
  '';

  # qBittorrent configuration template
  qbittorrentConfig = pkgs.writeText "qBittorrent.conf" ''
    [Application]
    FileLogger\Age=1
    FileLogger\AgeType=1
    FileLogger\Backup=true
    FileLogger\DeleteOld=true
    FileLogger\Enabled=true
    FileLogger\MaxSizeBytes=66560
    FileLogger\Path=${logsDir}

    [AutoRun]
    enabled=true

    [BitTorrent]
    Session\DefaultSavePath=${cfg.downloadPath}
    Session\DisableAutoTMMByDefault=false
    Session\DisableAutoTMMTriggers\CategorySavePathChanged=false
    Session\DisableAutoTMMTriggers\DefaultSavePathChanged=false
    Session\ExcludedFileNames=
    Session\GlobalUPSpeedLimit=200
    Session\Port=${toString cfg.torrentPort}
    Session\QueueingSystemEnabled=false
    Session\SSL\Port=30088
    Session\SubcategoriesEnabled=true
    Session\Tags=${builtins.concatStringsSep ", " cfg.tags}
    Session\UseCategoryPathsInManualMode=true
    Session\Interface=
    Session\InterfaceAddress=0.0.0.0
    Session\InterfaceName=
    Session\AddExtensionToIncompleteFiles=false
    Session\Encryption=1
    Session\ForceProxy=false
    Session\ProxyType=-1

    [Meta]
    MigrationVersion=8

    [Preferences]
    General\Locale=en
    MailNotification\req_auth=true
    WebUI\AuthSubnetWhitelist=@Invalid()
    WebUI\Password_PBKDF2="@ByteArray(xkVo9KYx/eCPQcIvc/JRYg==:ZyXmvUlrDL6ebMsZxdvsCA1d6dmgQSjhAn2RVEx6ZDCVwuG3o/QZ9jE2eL/XwcO4+yDSJBVhrFvp58kwmhVgsA==)"
    WebUI\Username=${userName}
    Downloads\OnFinish\Enabled=true
    Downloads\OnFinish\Program=${onFinishScript} "%F" "%N" "%I"
    Connection\PortRangeMin=${toString cfg.torrentPort}
    Connection\UPnP=false
    Connection\UseUPnPForWebUI=false
    Advanced\AnonymousMode=false
    Advanced\IgnoreLimitsLAN=true
    Advanced\IncludeOverhead=false
    Advanced\osCache=true
    Advanced\OutgoingPortsMax=0
    Advanced\OutgoingPortsMin=0

    [RSS]
    AutoDownloader\DownloadRepacks=true
    AutoDownloader\SmartEpisodeFilter=s(\\d+)e(\\d+), (\\d+)x(\\d+), "(\\d{4}[.\\-]\\d{1,2}[.\\-]\\d{1,2})", "(\\d{1,2}[.\\-]\\d{1,2}[.\\-]\\d{4})"
  '';

  # Generate categories.json from cfg.categories
  categoriesJson = pkgs.writeText "categories.json" (
    builtins.toJSON (
      builtins.listToAttrs (
        map (category: {
          name = category;
          value = {
            save_path = "";
          };
        }) cfg.categories
      )
    )
  );

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

    webPort = mkOpt types.port defaults.ports.qbittorrent.web "Port for the qBittorrent web interface";

    torrentPort =
      mkOpt types.port defaults.ports.qbittorrent.torrent
        "Port for BitTorrent protocol (incoming connections)";

    downloadPath = mkOpt types.str "/data/torrents" "Base download path for qBittorrent";

    tags = mkOption {
      type = types.listOf types.str;
      default = [
        "Action"
        "Comedy"
        "Drama"
        "Horror"
        "Thriller"
        "Sci-Fi"
        "Documentary"
        "Animation"
        "Family"
        "Kids"
      ];
      example = [
        "Action"
        "Comedy"
        "Drama"
        "Horror"
        "Thriller"
        "Sci-Fi"
        "Documentary"
        "Animation"
      ];
      description = ''
        List of tags for qBittorrent torrents. These tags can be used to organize and filter torrents.
        Tags are comma-separated in the qBittorrent configuration.
        Default includes most popular movie/TV genres.
      '';
    };

    package = mkOpt types.package pkgs.qbittorrent-nox "qBittorrent package to use";
  };

  config = mkIf cfg.enable {

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
      startLimitBurst = 5;
      startLimitIntervalSec = 500;

      serviceConfig = {
        Type = "exec";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox --webui-port=${toString cfg.webPort}";
        Restart = "on-failure";
        RestartSec = "5s";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [
          cfg.homeDir
          cfg.downloadPath
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
        # Relaxed system call filter
        SystemCallFilter = [
          "@system-service"
          "@network-io"
          "~@privileged"
        ];
      };

      preStart = ''

        # Copy configuration files with proper ownership
        cp ${qbittorrentConfig} ${configDir}/qBittorrent.conf
        cp ${categoriesJson} ${configDir}/categories.json
                
      '';

    };

    # Open firewall ports
    networking.firewall = {
      allowedTCPPorts = [
        cfg.webPort # Web UI
        cfg.torrentPort # BitTorrent protocol
      ];
      allowedUDPPorts = [
        cfg.torrentPort # DHT and other UDP traffic
      ];
    };

    # Ensure the media directories exist and have correct permissions
    systemd.tmpfiles.rules =
      [
        "d ${cfg.downloadPath} 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.homeDir} 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.homeDir}/.config 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.homeDir}/.config/qBittorrent 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.homeDir}/.local 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.homeDir}/.local/share 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.homeDir}/.local/share/qBittorrent 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.homeDir}/.local/share/qBittorrent/logs 0755 ${cfg.user} ${cfg.group} -"
      ]
      ++ map (
        category: "d ${cfg.downloadPath}/${category} 0755 ${cfg.user} ${cfg.group} -"
      ) cfg.categories;

    # Add qBittorrent package to system packages
    environment.systemPackages = [ pkgs.qbittorrent-nox ];

    environment.persistence.${persistence.root config}.directories = [
      cfg.homeDir
      cfg.downloadPath
    ];

  };
}
