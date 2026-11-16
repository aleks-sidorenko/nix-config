{ lib, ... }:
let
  webPort = 8080;
  torrentPort = 17348;
  uploadSpeedLimit = 200;
  dataDir = "/var/lib/qbittorrent";
  configDir = "${dataDir}/.config/qBittorrent";
  logsDir = "${dataDir}/.local/share/qBittorrent/logs";
  user = "qbittorrent";
in
{
  den.aspects.services.qbittorrent = {
    persist.directories = [ dataDir ];
    installChecks = [ ''machine.wait_for_unit("qbittorrent.service")'' ];
    settings.webUser = lib.mkOption {
      type = lib.types.str;
      description = "User the web UI authenticates as; its password is the `service-qbittorrent-<user>-password` secret.";
    };

    vhosts = [
      {
        name = "qbittorrent";
        port = webPort;
        requiresProxyAuth = true;
      }
    ];

    nixos =
      {
        config,
        host,
        pkgs,
        ...
      }:
      let
        media = import ./_media.nix host.mediaRoot;
        inherit (media) group;
        downloadCategories = [
          media.categories.movies
          media.categories.series
        ];

        webUser = host.settings.services.qbittorrent.webUser;
        secret = "service-qbittorrent-${webUser}-password";

        torrentScriptParams = ''\"%N\" \"%L\" \"%G\" \"%F\" \"%R\" \"%D\" \"%C\" \"%Z\" \"%T\" \"%I\" \"%J\" \"%K\"'';

        onFinishScript = pkgs.writeShellScript "qbittorrent-on-finish" ''
          set -euo pipefail
          # The *arr apps import by hardlink; this only logs and opens up permissions.
          QB_NAME=$1 QB_ROOT_PATH=$5 QB_SAVE_PATH=$6

          target="$QB_ROOT_PATH"
          if [ -z "$target" ] || [ ! -e "$target" ]; then
            target="$QB_SAVE_PATH"
          fi

          if [ -n "$target" ] && [ -e "$target" ]; then
            chmod -R 775 "$target"
          fi

          ${pkgs.systemd}/bin/systemd-cat -t qbittorrent echo "Download completed: $QB_NAME"
        '';

        categoriesJson = pkgs.writeText "categories.json" (
          builtins.toJSON (
            lib.genAttrs downloadCategories (_: {
              save_path = "";
            })
          )
        );
      in
      {
        sops.secrets.${secret} = {
          owner = user;
          inherit group;
          mode = "0400";
        };

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
            enabled=true
            program=${onFinishScript} ${torrentScriptParams}

            [BitTorrent]
            Session\DefaultSavePath=${media.downloadRoot}
            Session\DisableAutoTMMByDefault=false
            Session\DisableAutoTMMTriggers\CategorySavePathChanged=false
            Session\DisableAutoTMMTriggers\DefaultSavePathChanged=false
            Session\ExcludedFileNames=
            Session\GlobalUPSpeedLimit=${toString uploadSpeedLimit}
            Session\Port=${toString torrentPort}
            Session\QueueingSystemEnabled=false
            Session\SSL\Port=30088
            Session\SubcategoriesEnabled=true
            Session\Tags=
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
            # vhost), so loopback, where every proxied request comes from, is
            # exempt, and so are the on-host clients that drive the API. The cost
            # is that this app's own logs and bans see the proxy, not the peer.
            WebUI\LocalHostAuth=false
            WebUI\AuthSubnetWhitelistEnabled=false
            WebUI\Password_PBKDF2="${config.sops.placeholder.${secret}}"
            WebUI\Username=${webUser}
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

        users.groups.${group} = { };
        users.users.${user} = {
          isSystemUser = true;
          inherit group;
          extraGroups = [ "users" ];
          home = dataDir;
          createHome = true;
          description = "qBittorrent daemon user";
        };

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
              media.downloadRoot
            ];

            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
              "AF_UNIX"
              "AF_NETLINK"
            ];
            CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
            LockPersonality = true;
            MemoryDenyWriteExecute = true;
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            SystemCallArchitectures = "native";
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

        # The web UI goes through the proxy on loopback; inbound peers don't.
        networking.firewall = {
          allowedTCPPorts = [ torrentPort ];
          allowedUDPPorts = [ torrentPort ];
        };

        systemd.tmpfiles.rules = [
          "d ${media.downloadRoot} 0775 ${user} ${group} -"
          "d ${dataDir} 0755 ${user} ${group} -"
          "d ${dataDir}/.config 0755 ${user} ${group} -"
          "d ${configDir} 0755 ${user} ${group} -"
          "d ${dataDir}/.local 0755 ${user} ${group} -"
          "d ${dataDir}/.local/share 0755 ${user} ${group} -"
          "d ${dataDir}/.local/share/qBittorrent 0755 ${user} ${group} -"
          "d ${logsDir} 0755 ${user} ${group} -"
        ]
        ++ map (category: "d ${media.downloadDir category} 0755 ${user} ${group} -") downloadCategories;

        environment.systemPackages = [ pkgs.qbittorrent-nox ];
      };
  };
}
