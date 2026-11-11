{
  config,
  inputs,
  lib,
  ...
}:
let
  c =
    (config.builders.testNixos {
      imports = with config.flake.modules.nixos; [
        qbittorrent
        sops
        nginx
      ];
    }).config;
  inherit (c.networking.firewall) allowedTCPPorts allowedUDPPorts;
in
{
  flake.modules.nixos.qbittorrent =
    { config, pkgs, ... }:
    let
      media = config.nix-config.media;
      user = "qbittorrent";
      inherit (media) group;
      dataDir = "/var/lib/qbittorrent";
      downloadDir = media.downloadRoot;
      categories = with media.categories; [
        movies
        series
      ];
      webPort = 8080;
      torrentPort = 17348;
      configDir = "${dataDir}/.config/qBittorrent";
      logsDir = "${dataDir}/.local/share/qBittorrent/logs";
      userName = config.constants.owner;

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

      # Generate categories.json from the categories
      categoriesJson = pkgs.writeText "categories.json" (
        builtins.toJSON (
          builtins.listToAttrs (
            map (category: {
              name = category;
              value = {
                save_path = "";
              };
            }) categories
          )
        )
      );
    in
    {
      imports = [ inputs.self.modules.nixos.media-library ];

      # SOPS secret for qBittorrent password
      sops.secrets."service-qbittorrent-${userName}-password" = {
        owner = user;
        inherit group;
        mode = "0400";
      };

      nix-config.nginx.virtualHosts.qbittorrent = {
        port = webPort;
        requiresProxyAuth = true;
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
          Session\DefaultSavePath=${downloadDir}
          Session\DisableAutoTMMByDefault=false
          Session\DisableAutoTMMTriggers\CategorySavePathChanged=false
          Session\DisableAutoTMMTriggers\DefaultSavePathChanged=false
          Session\ExcludedFileNames=
          Session\GlobalUPSpeedLimit=${toString 200}
          Session\Port=${toString torrentPort}
          Session\QueueingSystemEnabled=${toString false}
          Session\SSL\Port=30088
          Session\SubcategoriesEnabled=true
          Session\Tags=${builtins.concatStringsSep ", " [ ]}
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
          WebUI\Address=127.0.0.1
          # Authentication belongs to the proxy (see requiresProxyAuth on the
          # vhost), so loopback — where every proxied request comes from — is
          # exempt, and so are the on-host clients that drive the API. The cost
          # is that this app's own logs and bans see the proxy, not the peer.
          WebUI\LocalHostAuth=false
          WebUI\AuthSubnetWhitelistEnabled=false
          WebUI\Password_PBKDF2="${config.sops.placeholder."service-qbittorrent-${userName}-password"}"
          WebUI\Username=${userName}
          Connection\PortRangeMin=${toString torrentPort}
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
        owner = user;
        inherit group;
        mode = "0400";
      };

      users.users.${user} = {
        isSystemUser = true;
        group = lib.mkForce group;
        extraGroups = [ "users" ];
        home = dataDir;
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
          User = user;
          Group = group;
          ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox --webui-port=${toString webPort}";
          Restart = "on-failure";
          RestartSec = "5s";

          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [
            dataDir
            downloadDir
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
          # cp keeps the source's mode; both sources are read-only, so an explicit
          # mode is required or qBittorrent can't rewrite its own config next start
          install -m 0600 ${config.sops.templates."qbittorrent.conf".path} ${configDir}/qBittorrent.conf
          install -m 0644 ${categoriesJson} ${configDir}/categories.json
        '';

      };

      networking.firewall = {
        # Web UI is reached through nginx (loopback); the peer port stays open
        # since inbound torrent connections don't go through the proxy.
        allowedTCPPorts = [
          torrentPort # BitTorrent protocol
        ];
        allowedUDPPorts = [
          torrentPort # DHT and other UDP traffic
        ];
      };

      # Ensure the media directories exist and have correct permissions
      systemd.tmpfiles.rules = [
        "d ${downloadDir} 0775 ${user} ${group} -"
        "d ${dataDir} 0755 ${user} ${group} -"
        "d ${dataDir}/.config 0755 ${user} ${group} -"
        "d ${dataDir}/.config/qBittorrent 0755 ${user} ${group} -"
        "d ${dataDir}/.local 0755 ${user} ${group} -"
        "d ${dataDir}/.local/share 0755 ${user} ${group} -"
        "d ${dataDir}/.local/share/qBittorrent 0755 ${user} ${group} -"
        "d ${dataDir}/.local/share/qBittorrent/logs 0755 ${user} ${group} -"
      ]
      ++ map (category: "d ${downloadDir}/${category} 0755 ${user} ${group} -") categories;

      # Add qBittorrent package to system packages
      environment.systemPackages = [ pkgs.qbittorrent-nox ];
    };

  evalTests = {
    qbittorrent-secret = {
      expr = c.sops.secrets ? "service-qbittorrent-alexander-password";
      expected = true;
    };
    # The web UI is reached through nginx only.
    qbittorrent-firewall = {
      expr = [
        (builtins.elem 17348 allowedTCPPorts)
        (builtins.elem 17348 allowedUDPPorts)
        (builtins.elem 8080 allowedTCPPorts)
      ];
      expected = [
        true
        true
        false
      ];
    };
    qbittorrent-category-dirs = {
      expr = builtins.all (r: builtins.elem r c.systemd.tmpfiles.rules) [
        "d /data/torrents/Movies 0755 qbittorrent media -"
        "d /data/torrents/Series 0755 qbittorrent media -"
      ];
      expected = true;
    };
    qbittorrent-webui-loopback = {
      expr = lib.hasInfix "WebUI\\Address=127.0.0.1" c.sops.templates."qbittorrent.conf".content;
      expected = true;
    };
  };
}
