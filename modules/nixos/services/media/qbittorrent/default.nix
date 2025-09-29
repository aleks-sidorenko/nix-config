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
  configDir = "${cfg.dataDir}/.config/qBittorrent";
  logsDir = "${cfg.dataDir}/.local/share/qBittorrent/logs";
  userName = lib.${namespace}.userName config;
  subnet = defaults.network.subnet;

  # Default categories for qBittorrent with subcategories
  defaultCategories = [
    "Videos"
    "Audio"
    "Books"
    "Software"
    "Other"
  ];

  torrentScriptVars =
    # bash
    ''
      export QB_NAME=''${1}          # Torrent Name
      export QB_CATEGORY=''${2}      # Category
      export QB_TAGS=''${3}          # Tags (separated by comma)
      export QB_CONTENT_PATH=''${4}  # Content Path (same as root path for multifile torrent)
      export QB_ROOT_PATH=''${5}     # Root path (first torrent subdirectory path)
      export QB_SAVE_PATH=''${6}     # Save Path
      export QB_NUM_FILES=''${7}     # Numbe of files
      export QB_NUM_BYTES=''${8}     # Torrent size in bytes
      export QB_TRACKER=''${9}       # Current tracker     
      export QB_INFOHASH1=''${10}    # Info hash v1
      export QB_INFOHASH2=''${11}    # Info hash v2
    '';
  torrentScriptParams = ''\"%N\" \"%L\" \"%G\" \"%F\" \"%R\" \"%D\" \"%C\" \"%Z\" \"%T\" \"%I\" \"%J\" \"%K\"'';

  onFinishScript = pkgs.writeShellScript "qbittorrent-on-finish" ''
    #!${pkgs.runtimeShell}
    set -euo pipefail
    # qBittorrent on-finish script for *arr integration
    # This script is called when a download completes
    # The *arr applications (Sonarr/Radarr) will handle the actual file moving via hardlinks

    ${torrentScriptVars}

    echo "$(date): Download completed"
    echo "  Name: $QB_NAME"
    echo "  Category: $QB_CATEGORY"
    echo "  Tags: $QB_TAGS"
    echo "  Content Path: $QB_CONTENT_PATH"
    echo "  Root Path: $QB_ROOT_PATH"
    echo "  Save Path: $QB_SAVE_PATH"
    echo "  Info Hash v1: $QB_INFOHASH1"
    echo "  Info Hash v2: $QB_INFOHASH2"

    target="$QB_ROOT_PATH"
    if [ -z "$target" ] || [ ! -e "$target" ]; then
      target="$QB_SAVE_PATH"
    fi

    if [ -n "$target" ] && [ -e "$target" ]; then
      chmod -R 775 "$target"
      echo "  Permissions set to 775"
    else
      echo "  Warning: target does not exist, skipping chmod"
    fi

    # Log to systemd journal for monitoring
    ${pkgs.systemd}/bin/systemd-cat -t qbittorrent echo "Download completed: $QB_NAME"
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
    dataDir = mkOpt types.str "/var/lib/qbittorrent" "Data directory for qBittorrent";
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
        Each category will have its own subdirectory structure under the downloadDir.
        Examples: "Video/Movies", "Video/Series/Anime", "Books/Fiction", etc.
      '';
    };

    user = mkOpt types.str "qbittorrent" "User to run qBittorrent as";

    group = mkOpt types.str config.${namespace}.services.media.group "Group to run qBittorrent as";

    webPort =
      mkOpt types.port defaults.network.ports.qbittorrent.web
        "Port for the qBittorrent web interface";

    torrentPort =
      mkOpt types.port defaults.network.ports.qbittorrent.torrent
        "Port for BitTorrent protocol (incoming connections)";

    downloadDir = mkOpt types.str "/data/torrents" "Base download directory for qBittorrent";

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

    userName = mkOption {
      type = types.str;
      readOnly = true;
      description = "Username for qBittorrent web interface authentication";
    };

    password = mkOption {
      type = types.str;
      readOnly = true;
      description = "Password for qBittorrent web interface authentication";
    };
  };

  config = mkIf cfg.enable {
    # SOPS secret for qBittorrent password
    sops.secrets."service-qbittorrent-${userName}-password" = {
      sopsFile = ../../../secrets.yaml;
      owner = cfg.user;
      group = cfg.group;
      mode = "0400";
    };

    ${namespace}.services.media.qbittorrent = {
      userName = userName;
      password = ""; # we allow local clients to connect without a password
    };

    # SOPS template for qBittorrent configuration with secret substitution
    sops.templates."qbittorrent.conf" = {
      content = ''
        [Application]
        FileLogger\Age=1
        FileLogger\AgeType=1
        FileLogger\Backup=true
        FileLogger\DeleteOld=true
        FileLogger\Enabled=true
        FileLogger\MaxSizeBytes=66560
        FileLogger\Path=${logsDir}

        [AutoRun]
        # OnTorrentAdded\Enabled=true
        # OnTorrentAdded\Program=''${onAddScript} ''${torrentScriptParams}
        enabled=true
        program=${onFinishScript} ${torrentScriptParams}

        [BitTorrent]
        Session\DefaultSavePath=${cfg.downloadDir}
        Session\DisableAutoTMMByDefault=false
        Session\DisableAutoTMMTriggers\CategorySavePathChanged=false
        Session\DisableAutoTMMTriggers\DefaultSavePathChanged=false
        Session\ExcludedFileNames=
        Session\GlobalUPSpeedLimit=200
        Session\Port=${toString cfg.torrentPort}
        Session\QueueingSystemEnabled=true
        Session\SSL\Port=30088
        Session\SubcategoriesEnabled=true
        Session\Tags=${builtins.concatStringsSep ", " cfg.tags}
        Session\UseCategoryPathsInManualMode=true
        Session\TorrentContentLayout=Subfolder
        Session\Interface=
        Session\InterfaceAddress=0.0.0.0
        Session\InterfaceName=
        Session\AddExtensionToIncompleteFiles=false
        Session\Encryption=1
        Session\ForceProxy=false
        Session\ProxyType=-1

        [LegalNotice]
        Accepted=true

        [Meta]
        MigrationVersion=8

        [Preferences]
        General\Locale=en
        MailNotification\req_auth=true
        WebUI\AuthSubnetWhitelist=@Invalid()

        WebUI\AuthSubnetWhitelist=${subnet}
        WebUI\AuthSubnetWhitelistEnabled=true
        WebUI\LocalHostAuth=false
        WebUI\Password_PBKDF2="${config.sops.placeholder."service-qbittorrent-${userName}-password"}"
        WebUI\Username=${userName}
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
      owner = cfg.user;
      group = cfg.group;
      mode = "0400";
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = mkForce cfg.group;
      extraGroups = [ "users" ];
      home = cfg.dataDir;
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
          cfg.dataDir
          cfg.downloadDir
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
        cp ${config.sops.templates."qbittorrent.conf".path} ${configDir}/qBittorrent.conf
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
        "d ${cfg.downloadDir} 0775 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir}/.config 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir}/.config/qBittorrent 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir}/.local 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir}/.local/share 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir}/.local/share/qBittorrent 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.dataDir}/.local/share/qBittorrent/logs 0755 ${cfg.user} ${cfg.group} -"
      ]
      ++ map (
        category: "d ${cfg.downloadDir}/${category} 0755 ${cfg.user} ${cfg.group} -"
      ) cfg.categories;

    # Add qBittorrent package to system packages
    environment.systemPackages = [ pkgs.qbittorrent-nox ];

  };
}
