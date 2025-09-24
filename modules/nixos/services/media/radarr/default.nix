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
  # Local paths that include the category
  mediaPath = "${cfg.mediaRoot}/${cfg.torrent.category}";
  downloadPath = "${cfg.downloadRoot}/${cfg.torrent.category}";

  # Function to create Radarr API requests
  mkRadarrRequest =
    {
      method,
      path,
      data ? null,
      description ? "",
    }:
    ''
      echo "${if description != "" then description else "Making ${method} request to ${path}"}"
      curl -sS -X ${method} \
        -H "X-Api-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        ${if data != null then "-d '${builtins.toJSON data}'" else ""} \
        "http://localhost:${toString cfg.webPort}${path}" || echo "Failed: ${description}"
    '';

  # Media management configuration for hardlinks
  mediaManagementConfig = {
    autoUnmonitorPreviouslyDownloadedMovies = false;
    recycleBin = "";
    recycleBinCleanupDays = 7;
    downloadPropersAndRepacks = "preferAndUpgrade";
    createEmptyMovieFolders = false;
    deleteEmptyFolders = false;
    fileDate = "none";
    rescanAfterRefresh = "always";
    autoRenameFolders = false;
    pathsDefaultStatic = false;
    setPermissionsLinux = false;
    chmodFolder = "755";
    chownGroup = "";
    skipFreeSpaceCheckWhenImporting = false;
    minimumFreeSpaceWhenImporting = 100;
    copyUsingHardlinks = cfg.torrent.useHardlinks;
    importExtraFiles = false;
    extraFileExtensions = "srt,nfo";
    enableMediaInfo = true;
    renameMovies = true;
    movieFolderFormat = "{Movie Title} ({Release Year})";
  };

  # Root folder configuration
  rootFolderConfig = {
    path = mediaPath;
    accessible = true;
    freeSpace = 0;
    unmappedFolders = [ ];
  };

  # Simple torrent client configuration
  torrentClientConfig = {
    enable = true;
    protocol = "torrent";
    priority = 1;
    removeCompletedDownloads = false;
    removeFailedDownloads = false;
    name = cfg.torrent.implementation;
    implementation = cfg.torrent.implementation;
    configContract = "${cfg.torrent.implementation}Settings";
    infoLink = "https://wiki.servarr.com/radarr/supported#${cfg.torrent.name}";
    fields = [
      {
        name = "host";
        value = cfg.torrent.host;
      }
      {
        name = "port";
        value = cfg.torrent.port;
      }
      {
        name = "useSsl";
        value = false;
      }
      {
        name = "urlBase";
        value = cfg.torrent.urlBase;
      }
      {
        name = "username";
        value = cfg.torrent.userName;
      }
      {
        name = "password";
        value = cfg.torrent.password;
      }
      {
        name = "movieCategory";
        value = cfg.torrent.category;
      }
      {
        name = "recentMoviePriority";
        value = 0;
      }
      {
        name = "olderMoviePriority";
        value = 0;
      }
      {
        name = "initialState";
        value = 0;
      }
      {
        name = "sequentialOrder";
        value = false;
      }
      {
        name = "firstAndLast";
        value = false;
      }
    ];
    tags = [ ];
  };

in
{
  options.${namespace}.services.media.radarr = {
    enable = mkEnableOption "Enable Radarr movie management";

    user = mkOpt types.str "radarr" "User to run Radarr as";

    group = mkOpt types.str config.${namespace}.services.media.group "Group to run Radarr as";

    dataDir = mkOpt types.str "/var/lib/radarr" "Directory where Radarr stores its data";

    downloadRoot = mkOpt types.str "/data/torrents" "Root directory for downloads";

    mediaRoot = mkOpt types.str "/data/media" "Root directory for media storage";

    package = mkOpt types.package pkgs.radarr "Radarr package to use";

    webPort = mkOpt types.port defaults.network.ports.radarr.web "Port for the Radarr web interface";

    config = {
      logLevel = mkOption {
        type = types.enum [
          "info"
          "debug"
          "trace"
          "warn"
          "error"
        ];
        default = "info";
        description = "Log level for Radarr";
      };

      bindAddress = mkOption {
        type = types.str;
        default = "*";
        description = "Bind address for Radarr web interface";
      };

      instanceName = mkOption {
        type = types.str;
        default = "Radarr";
        description = "Instance name for Radarr";
      };
    };

    torrent = {
      enable = mkEnableOption "Enable torrent client integration";

      name = mkOption {
        type = types.enum [
          "qbittorrent"
          "transmission"
          "deluge"
        ];
        default = "qbittorrent";
        description = "Display name for the torrent client";
      };

      implementation = mkOption {
        type = types.str;
        default = "QBittorrent";
        description = "Implementation name for the torrent client";
      };

      category = mkOpt types.str "Movies" "Category name for torrent client to organize movie downloads";

      useHardlinks = mkOption {
        type = types.bool;
        default = true;
        description = "Use hardlinks instead of copying files, allowing torrents to continue seeding";
      };

      host = mkOpt types.str "localhost" "Torrent client host";

      port = mkOption {
        type = types.port;
        default = 8080;
        description = "Torrent client web interface port";
      };

      urlBase = mkOption {
        type = types.str;
        default = "";
        description = "URL base path for the torrent client (auto-detected if not specified)";
      };

      userName = mkOpt types.str "" "Username for torrent client authentication";

      password = mkOpt types.str "" "Password for torrent client authentication";

    };

  };

  config = mkIf cfg.enable {
    # SOPS secret for Radarr API key
    sops.secrets."service-radarr-api-key" = {
      sopsFile = ../../../secrets.yaml;
      owner = cfg.user;
      group = cfg.group;
      mode = "0400";
    };

    # SOPS template for Radarr configuration with secret substitution
    sops.templates."radarr-config.xml" = {
      content = ''
        <Config>
          <BindAddress>${cfg.config.bindAddress}</BindAddress>
          <Port>${toString cfg.webPort}</Port>
          <ApiKey>${config.sops.placeholder."service-radarr-api-key"}</ApiKey>
          <AuthenticationMethod>External</AuthenticationMethod>
          <LogLevel>${cfg.config.logLevel}</LogLevel>
          <AnalyticsEnabled>False</AnalyticsEnabled>
          <LogDbEnabled>False</LogDbEnabled>
          <InstanceName>${cfg.config.instanceName}</InstanceName>
          <!-- <SslPort>9898</SslPort> -->
          <!-- <EnableSsl>False</EnableSsl> -->
          <!-- <LaunchBrowser>True</LaunchBrowser> -->
          <!-- <AuthenticationRequired>DisabledForLocalAddresses</AuthenticationRequired> -->
          <!-- <Branch>master</Branch> -->
          <!-- <SslCertPath></SslCertPath> -->
          <!-- <SslCertPassword></SslCertPassword> -->
          <!-- <UrlBase></UrlBase> -->
        </Config>
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
      description = "Radarr movie management user";
    };

    services.radarr = {
      enable = cfg.enable;
      package = cfg.package;
      user = cfg.user;
      group = cfg.group;
      settings.server.port = cfg.webPort;
      openFirewall = true;
      dataDir = cfg.dataDir;
    };

    # Add preStart script to copy SOPS-generated configuration
    systemd.services.radarr = {
      preStart = ''
        echo "Copying Radarr configuration XML with secrets..."        
        cp ${config.sops.templates."radarr-config.xml".path} ${cfg.dataDir}/config.xml        
        echo "Radarr configuration XML with secrets copied successfully"
      '';
    };

    # Configure Radarr with torrent client integration and hardlinks
    systemd.services.radarr-config = mkIf cfg.torrent.enable {
      description = "Configure Radarr for torrent integration and hardlinks";
      after = [ "radarr.service" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [
        curl
        jq
      ];

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        RemainAfterExit = true;
      };

      script = ''
        # Read API key from SOPS secret first
        API_KEY=$(cat ${config.sops.secrets."service-radarr-api-key".path})
        echo "Configuring Radarr with API key from SOPS"

        # Wait for Radarr to be ready using mkRadarrRequest
        echo "Waiting for Radarr to be available..."
        until ${
          mkRadarrRequest {
            method = "GET";
            path = "/api/v3/system/status";
            description = "Checking Radarr system status";
          }
        } >/dev/null 2>&1; do
          sleep 5
          echo "Radarr not available yet, retrying..."
        done

        # Configure media management settings for hardlinks
        ${lib.optionalString cfg.torrent.useHardlinks (mkRadarrRequest {
          method = "PUT";
          path = "/api/v3/config/mediamanagement";
          data = mediaManagementConfig;
          description = "Configuring media management for hardlinks";
        })}

        # Configure root folder
        ${mkRadarrRequest {
          method = "POST";
          path = "/api/v3/rootfolder";
          data = rootFolderConfig;
          description = "Adding root folder for movies";
        }}

        # Configure download client
        ${mkRadarrRequest {
          method = "POST";
          path = "/api/v3/downloadclient";
          data = torrentClientConfig;
          description = "Adding torrent download client";
        }}

        echo "Radarr configuration completed successfully"
      '';
    };

    # Ensure directories exist and have correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
      # Create root directories
      "d ${cfg.downloadRoot} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.mediaRoot} 0755 ${cfg.user} ${cfg.group} -"
      # Create category-specific directories
      "d ${downloadPath} 0755 ${cfg.user} ${cfg.group} -"
      "d ${mediaPath} 0755 ${cfg.user} ${cfg.group} -"
    ];

    # Add Radarr package to system packages
    environment.systemPackages = [ cfg.package ];

    # Configure filesystem attributes for hardlinks support
    assertions = lib.optionals cfg.torrent.useHardlinks [
      {
        assertion = cfg.torrent.enable;
        message = "Hardlinks require torrent integration to be enabled";
      }
    ];

    # Persistence for important directories
    environment.persistence.${persistence.root config}.directories = [
      cfg.dataDir
      mediaPath
    ];

  };
}
