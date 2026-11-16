{
  config,
  den,
  lib,
  ...
}:
let
  user = "restic";
  group = "backup";
  dataDir = "/var/lib/restic";

  exclude = [
    # Temporary and log files
    "*.tmp"
    "*.cache"
    "*.log"
    "/var/cache"
    "/var/tmp"
    "/var/log"

    # User media files, we backup them on separate media
    "/home/*/Pictures"
    "/home/*/Videos"

    # User cache directories
    "/home/*/.cache"
    "/home/*/.local/cache"
    "/home/*/.local/share/Trash"

    # Browser caches
    "/home/*/.mozilla/firefox/*/cache2"
    "/home/*/.config/*/Cache"

    # Package manager caches
    "/home/*/.npm/_cacache"
    "/home/*/.cargo/registry"
    "/home/*/.cargo/git"
    "/home/*/snap/*/common/.cache"

    # Haskell build artifacts
    "/home/*/.stack-work"
    "*/.stack-work"
    "/home/*/.cabal-sandbox"
    "/home/*/.ghc"
    "*/dist"
    "*/dist-newstyle"

    # Java build artifacts
    "*/target"
    "*/build"
    "/home/*/.gradle"
    "/home/*/.m2/repository"
    "/home/*/.ivy2"
    "*.class"
  ];

  inherit (import ../_lib/install-test.nix { inherit den lib; }) perTestedHost;

  scheduled = system: system.config.systemd.timers.restic-backups-default.enable;
in
{
  den.aspects.services.restic = {
    settings.bucketUrl = lib.mkOption {
      type = lib.types.str;
      default = "s3:https://4e18ae7a3707f53f8d7cd82fb8e6abad.r2.cloudflarestorage.com/backups";
      description = "Bucket holding one restic repository per host.";
    };

    nixos =
      {
        backup,
        config,
        host,
        pkgs,
        ...
      }:
      let
        root = host.settings.storage.impermanence.root;
        # One repository per host, so hosts never share one or its lock.
        repository = "${host.settings.services.restic.bucketUrl}/${host.name}";
        passwordFile = config.sops.secrets."service-restic-password".path;
        owned = {
          owner = user;
          inherit group;
          mode = "0400";
        };
      in
      {
        environment.systemPackages = [ pkgs.restic ];
        environment.sessionVariables = {
          RESTIC_PASSWORD_FILE = passwordFile;
          RESTIC_REPOSITORY = repository;
        };

        sops.secrets = {
          "service-restic-password" = owned;
          "service-restic-r2-access-key-id" = { };
          "service-restic-r2-secret-access-key" = { };
        };

        # R2 speaks S3 and takes `auto` as its region.
        sops.templates."restic-r2.env" = owned // {
          content = ''
            AWS_ACCESS_KEY_ID=${config.sops.placeholder."service-restic-r2-access-key-id"}
            AWS_SECRET_ACCESS_KEY=${config.sops.placeholder."service-restic-r2-secret-access-key"}
            AWS_DEFAULT_REGION=auto
          '';
        };

        services.restic.backups.default = {
          inherit
            user
            repository
            passwordFile
            ;
          environmentFile = config.sops.templates."restic-r2.env".path;
          paths = [
            "/home"
            "/root"
            root
          ]
          ++ lib.concatMap (e: e.paths or [ ]) backup;
          # Backups read state from the persistence root, so excludes must name paths there.
          exclude =
            exclude
            ++ map (path: root + path) (
              [
                "/var/cache"
                "/var/tmp"
                "/var/log"
              ]
              ++ lib.concatMap (e: e.exclude or [ ]) backup
            );
          initialize = true;
          pruneOpts = [
            "--keep-daily 7"
            "--keep-weekly 4"
            "--keep-monthly 6"
            "--keep-yearly 2"
          ];
          checkOpts = [ "--read-data-subset=5%" ];
          timerConfig = {
            OnCalendar = "*-*-* 03:00:00";
            # A missed night is skipped rather than run at boot.
            Persistent = false;
            RandomizedDelaySec = "30m";
          };
        };

        # The install test VM has no network, so a backup could only fail.
        installTest.extraConfig.systemd.timers.restic-backups-default.enable = lib.mkForce false;

        users.users.${user} = {
          isSystemUser = true;
          inherit group;
          home = dataDir;
          createHome = true;
          description = "Restic backup user";
        };
        users.groups.${group} = { };

        systemd.tmpfiles.rules = [ "d ${dataDir} 0700 ${user} ${group} -" ];

        # Reads every file without running as root.
        systemd.services.restic-backups-default.serviceConfig = {
          AmbientCapabilities = [ "CAP_DAC_READ_SEARCH" ];
          CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" ];
        };
      };
  };

  evalTests.install-disables-backup-timer =
    perTestedHost den.aspects.services.restic
      (name: host: {
        installed = scheduled (config.installedSystem host);
        real = scheduled config.flake.nixosConfigurations.${name};
      })
      {
        installed = false;
        real = true;
      };
}
