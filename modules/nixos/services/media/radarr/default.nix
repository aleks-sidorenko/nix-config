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
  userName = lib.${namespace}.userName config;
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
      echo "${if description != "" then description else "Making ${method} request to ${path}"}" >&2
      curl -sS -X ${method} \
        -H "X-Api-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        ${if data != null then "-d '${builtins.toJSON data}'" else ""} \
        "http://localhost:${toString cfg.webPort}${path}" || { echo "Failed: ${description}" >&2; exit 1; }
    '';

  # Media management configuration for hardlinks
  mediaManagementConfig = {
    autoUnmonitorPreviouslyDownloadedMovies = false;
    recycleBin = "";
    recycleBinCleanupDays = 7;
    downloadPropersAndRepacks = "preferAndUpgrade";
    createEmptyMovieFolders = true;
    deleteEmptyFolders = true;
    fileDate = "none";
    rescanAfterRefresh = "always";
    autoRenameFolders = true;
    pathsDefaultStatic = false;
    setPermissionsLinux = false;
    chmodFolder = "755";
    chownGroup = cfg.group;
    skipFreeSpaceCheckWhenImporting = false;
    minimumFreeSpaceWhenImporting = 100;
    copyUsingHardlinks = cfg.torrent.useHardlinks;
    importExtraFiles = false;
    extraFileExtensions = "srt,nfo";
    enableMediaInfo = true;
  };

  # Root folder configuration
  rootFolderConfig = {
    path = mediaPath;
    accessible = true;
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
        value = 1;
      }
      {
        name = "olderMoviePriority";
        value = 1;
      }
      {
        name = "initialState";
        value = 1;
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

  # Function to create indexer configurations with SOPS secret substitution
  mkIndexerConfig = name: indexer: 
    let
      # Replace API key field values with SOPS placeholders if the secret exists
      processFields = fields:
        map (field: 
          if field.name == "apiKey" && indexer.enable && field.value == ""
          then field // { value = "\${API_KEY_${lib.toUpper name}}"; }
          else field
        ) fields;
    in {
      enable = true;
      name = indexer.name;
      implementation = indexer.implementation;
      configContract = "${indexer.implementation}Settings";
      infoLink = indexer.infoLink or "https://wiki.servarr.com/radarr/supported-indexers";
      protocol = indexer.protocol or "torrent";
      priority = indexer.priority or 25;
      downloadClientId = 0;
      fields = processFields indexer.fields;
      tags = indexer.tags or [ ];
    };

  # Built-in indexer configurations
  indexerConfigs = lib.mapAttrs (name: indexer: mkIndexerConfig name indexer) (
    lib.filterAttrs (name: indexer: indexer.enable) cfg.indexers
  );

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

    indexers = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          enable = mkEnableOption "Enable this indexer";

          name = mkOption {
            type = types.str;
            description = "Display name for the indexer";
          };

          implementation = mkOption {
            type = types.str;
            description = "Indexer implementation name";
          };

          infoLink = mkOption {
            type = types.str;
            default = "https://wiki.servarr.com/radarr/supported-indexers";
            description = "Link to indexer information";
          };

          protocol = mkOption {
            type = types.enum [ "torrent" "usenet" ];
            default = "torrent";
            description = "Protocol used by the indexer";
          };

          priority = mkOption {
            type = types.int;
            default = 25;
            description = "Priority of the indexer (1-50, lower is higher priority)";
          };

          fields = mkOption {
            type = types.listOf (types.attrsOf types.anything);
            description = "Configuration fields for the indexer";
          };

          tags = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Tags to associate with the indexer";
          };
        };
      });
      default = {
        yts = {
          enable = true;
          name = "YTS";
          implementation = "YTS";
          infoLink = "https://wiki.servarr.com/radarr/supported-indexers#yts";
          protocol = "torrent";
          priority = 25;
          fields = [
            {
              name = "baseUrl";
              value = "https://yts.mx";
            }
          ];
        };
        
        jackett = {
          enable = false;
          name = "Jackett";
          implementation = "TorznabSettings";
          infoLink = "https://wiki.servarr.com/radarr/supported-indexers#torznab";
          protocol = "torrent";
          priority = 20;
          fields = [
            {
              name = "baseUrl";
              value = "http://localhost:9117/api/v2.0/indexers/all/results/torznab/";
            }
            {
              name = "apiKey";
              value = "";
            }
            {
              name = "categories";
              value = [2000, 2010, 2020, 2030, 2040, 2045, 2050, 2060, 2070, 2080];
            }
            {
              name = "earlyReleaseLimit";
              value = "";
            }
            {
              name = "additionalParameters";
              value = "";
            }
          ];
        };

        prowlarr = {
          enable = false;
          name = "Prowlarr";
          implementation = "ProwlarrSettings";
          infoLink = "https://wiki.servarr.com/radarr/supported-indexers#prowlarr";
          protocol = "torrent";
          priority = 15;
          fields = [
            {
              name = "prowlarrUrl";
              value = "http://localhost:9696";
            }
            {
              name = "apiKey";
              value = "";
            }
            {
              name = "syncCategories";
              value = [2000, 2010, 2020, 2030, 2040, 2045, 2050, 2060, 2070, 2080];
            }
          ];
        };
      };
      description = "Indexer configurations for Radarr";
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

    # SOPS secrets for indexer API keys
    sops.secrets = lib.mkMerge (lib.mapAttrsToList (name: indexerConfig: 
      lib.mkIf (indexerConfig.enable && (lib.any (field: field.name == "apiKey") indexerConfig.fields)) {
        "service-radarr-indexer-${name}-api-key" = {
          sopsFile = ../../../secrets.yaml;
          owner = cfg.user;
          group = cfg.group;
          mode = "0400";
        };
      }
    ) cfg.indexers);

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
        ${lib.optionalString cfg.torrent.useHardlinks ''
          echo "Getting current media management configuration..."
          MEDIA_MGMT_CONFIG=$(${
            mkRadarrRequest {
              method = "GET";
              path = "/api/v3/config/mediamanagement";
              description = "Getting current media management configuration";
            }
          })

          MEDIA_MGMT_ID=$(echo "$MEDIA_MGMT_CONFIG" | jq -r '.id // 1')
          echo "Media management ID: $MEDIA_MGMT_ID" >&2

          ${mkRadarrRequest {
            method = "PUT";
            path = "/api/v3/config/mediamanagement/$MEDIA_MGMT_ID";
            data = mediaManagementConfig;
            description = "Updating media management for hardlinks";
          }}
        ''}

        # Configure root folder - check if exists first
        echo "Checking for existing root folders..."
        EXISTING_FOLDERS=$(${
          mkRadarrRequest {
            method = "GET";
            path = "/api/v3/rootfolder";
            description = "Getting existing root folders";
          }
        })
        echo "EXISTING_FOLDERS: $EXISTING_FOLDERS" >&2

        # Check if our root folder already exists by path
        if [ -n "$EXISTING_FOLDERS" ] && [ "$EXISTING_FOLDERS" != "null" ]; then
          FOLDER_EXISTS=$(echo "$EXISTING_FOLDERS" | jq -r --arg path "${mediaPath}" '.[] | select(.path == $path) | .id // empty' 2>/dev/null || echo "")
        else
          FOLDER_EXISTS=""
        fi

        echo "FOLDER_EXISTS: $FOLDER_EXISTS" >&2

        if [ -n "$FOLDER_EXISTS" ]; then
          echo "Root folder '${mediaPath}' already exists with ID: $FOLDER_EXISTS"
        else
          echo "Adding root folder '${mediaPath}'..."
          ${mkRadarrRequest {
            method = "POST";
            path = "/api/v3/rootfolder";
            data = rootFolderConfig;
            description = "Adding root folder for movies";
          }}
        fi

        # Configure download client - check if exists first, update if it does
        echo "Checking for existing download clients..."
        EXISTING_CLIENTS=$(${
          mkRadarrRequest {
            method = "GET";
            path = "/api/v3/downloadclient";
            description = "Getting existing download clients";
          }
        })
        echo "EXISTING_CLIENTS: $EXISTING_CLIENTS" >&2

        # Check if our client already exists by name
        if [ -n "$EXISTING_CLIENTS" ] && [ "$EXISTING_CLIENTS" != "null" ]; then
          CLIENT_EXISTS=$(echo "$EXISTING_CLIENTS" | jq -r --arg name "${cfg.torrent.implementation}" '.[] | select(.name == $name) | .id // empty' 2>/dev/null || echo "")
        else
          CLIENT_EXISTS=""
        fi

        echo "CLIENT_EXISTS: $CLIENT_EXISTS" >&2

        if [ -n "$CLIENT_EXISTS" ]; then
          echo "Download client '${cfg.torrent.implementation}' already exists with ID: $CLIENT_EXISTS, updating configuration..."
          
          # Create updated config with the existing ID
          UPDATED_CLIENT_CONFIG=$(echo '${builtins.toJSON torrentClientConfig}' | jq --argjson id "$CLIENT_EXISTS" '. + {id: $id}')
          
          echo "Updating download client with ID: $CLIENT_EXISTS" >&2
          echo "Updated config: $UPDATED_CLIENT_CONFIG" >&2
          curl -sS -X PUT \
            -H "X-Api-Key: $API_KEY" \
            -H "Content-Type: application/json" \
            -d "$UPDATED_CLIENT_CONFIG" \
            "http://localhost:${toString cfg.webPort}/api/v3/downloadclient/$CLIENT_EXISTS" || { echo "Failed to update download client with ID $CLIENT_EXISTS" >&2; exit 1; }
        else
          echo "Adding new download client '${cfg.torrent.implementation}'..."
          ${mkRadarrRequest {
            method = "POST";
            path = "/api/v3/downloadclient";
            data = torrentClientConfig;
            description = "Adding torrent download client";
          }}
        fi

        # Configure indexers
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: indexerConfig: 
          let
            hasApiKey = lib.any (field: field.name == "apiKey") indexerConfig.fields;
            apiKeyVar = "API_KEY_${lib.toUpper name}";
            configWithSubstitution = mkIndexerConfig name indexerConfig;
          in ''
            echo "Configuring indexer: ${indexerConfig.name}..."
            
            ${lib.optionalString hasApiKey ''
              # Read API key from SOPS secret if it exists
              if [ -f "${config.sops.secrets."service-radarr-indexer-${name}-api-key".path or ""}" ]; then
                ${apiKeyVar}=$(cat "${config.sops.secrets."service-radarr-indexer-${name}-api-key".path or ""}")
                echo "Using SOPS secret for ${indexerConfig.name} API key"
              else
                ${apiKeyVar}=""
                echo "No SOPS secret found for ${indexerConfig.name}, using empty API key"
              fi
            ''}

            EXISTING_INDEXERS=$(${
              mkRadarrRequest {
                method = "GET";
                path = "/api/v3/indexer";
                description = "Getting existing indexers";
              }
            })
            echo "EXISTING_INDEXERS: $EXISTING_INDEXERS" >&2

            # Check if our indexer already exists by name
            if [ -n "$EXISTING_INDEXERS" ] && [ "$EXISTING_INDEXERS" != "null" ]; then
              INDEXER_EXISTS=$(echo "$EXISTING_INDEXERS" | jq -r --arg name "${indexerConfig.name}" '.[] | select(.name == $name) | .id // empty' 2>/dev/null || echo "")
            else
              INDEXER_EXISTS=""
            fi

            echo "INDEXER_EXISTS: $INDEXER_EXISTS" >&2

            # Prepare the indexer configuration JSON with variable substitution
            INDEXER_CONFIG='${builtins.toJSON configWithSubstitution}'
            ${lib.optionalString hasApiKey ''
              INDEXER_CONFIG=$(echo "$INDEXER_CONFIG" | sed "s/\\\${apiKeyVar}/''$${apiKeyVar}/g")
            ''}

            if [ -n "$INDEXER_EXISTS" ]; then
              echo "Indexer '${indexerConfig.name}' already exists with ID: $INDEXER_EXISTS, updating configuration..."
              
              # Create updated config with the existing ID
              UPDATED_INDEXER_CONFIG=$(echo "$INDEXER_CONFIG" | jq --argjson id "$INDEXER_EXISTS" '. + {id: $id}')
              
              echo "Updating indexer with ID: $INDEXER_EXISTS" >&2
              echo "Updated config: $UPDATED_INDEXER_CONFIG" >&2
              curl -sS -X PUT \
                -H "X-Api-Key: $API_KEY" \
                -H "Content-Type: application/json" \
                -d "$UPDATED_INDEXER_CONFIG" \
                "http://localhost:${toString cfg.webPort}/api/v3/indexer/$INDEXER_EXISTS" || { echo "Failed to update indexer ${indexerConfig.name} with ID $INDEXER_EXISTS" >&2; }
            else
              echo "Adding new indexer '${indexerConfig.name}'..."
              curl -sS -X POST \
                -H "X-Api-Key: $API_KEY" \
                -H "Content-Type: application/json" \
                -d "$INDEXER_CONFIG" \
                "http://localhost:${toString cfg.webPort}/api/v3/indexer" || { echo "Failed to add indexer ${indexerConfig.name}" >&2; }
            fi
          ''
        ) (lib.filterAttrs (name: indexer: indexer.enable) cfg.indexers))}

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
