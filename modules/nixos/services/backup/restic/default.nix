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
  cfg = config.${namespace}.services.backup.restic;

  repository = "rest:http://${hosts.local "restic"}";
  paths = [
    "/home"
    "/root"
  ]
  ++ persistence.dirs config
  ++ cfg.extraPaths;

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
  ]
  ++ (map (persistence.resolve config) [
    "/var/cache"
    "/var/tmp"
    "/var/log"
  ]);

in
{
  options.${namespace}.services.backup.restic = {
    enable = mkEnableOption "Enable Restic backup client";

    package = mkOpt types.package pkgs.restic "Restic package to use";

    user = mkOpt types.str "restic" "User to run Restic backups as";

    group = mkOpt types.str config.${namespace}.services.backup.group "Group to run Restic backups as";

    dataDir = mkOpt types.str "/var/lib/restic" "Data directory for Restic backup service";

    repository = mkOpt types.str repository "Restic repository URL (e.g., rest:http://restic.local)";

    repositoryFile = mkOpt (types.nullOr types.path) null "Path to file containing repository URL";

    passwordFile =
      mkOpt types.path config.sops.secrets."service-restic-password".path
        "Path to file containing repository password";

    paths = mkOpt (types.listOf types.str) paths "List of paths to backup";

    extraPaths =
      mkOpt (types.listOf types.str) [ ]
        "Additional paths to include in backups (appended to the computed defaults)";

    exclude = mkOpt (types.listOf types.str) exclude "List of patterns to exclude from backup";

    timerConfig = mkOpt types.attrs {
      OnCalendar = "*-*-* 03:00:00"; # Run at 03:00 every day
      Persistent = false; # Don't run missed backups after wake/boot
      RandomizedDelaySec = "30m"; # Random delay up to 30 min to avoid thundering herd
    } "Systemd timer configuration for automatic backups";

    pruneOpts = mkOpt (types.listOf types.str) [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
      "--keep-yearly 2"
    ] "Options for pruning old backups";

    initialize = mkBoolOpt true "Initialize the repository if it doesn't exist";

    checkOpts = mkOpt (types.listOf types.str) [
      "--read-data-subset=5%"
    ] "Options for checking repository integrity";

    backupPrepareCommand = mkOpt (types.nullOr types.str) null "Command to run before backup";

    backupCleanupCommand = mkOpt (types.nullOr types.str) null "Command to run after backup";

    extraOptions = mkOpt (types.listOf types.str) [ ] "Extra options to pass to restic";

    rcloneConfigFile =
      mkOpt (types.nullOr types.path) null
        "Path to rclone config file (if using rclone backend)";

    environmentFile =
      mkOpt (types.nullOr types.path) null
        "Environment file containing additional secrets";
  };

  config = mkIf cfg.enable {
    # Add Restic package to system packages
    environment.systemPackages = [ cfg.package ];

    # Set environment variables for CLI usage
    environment.sessionVariables = {
      RESTIC_PASSWORD_FILE = cfg.passwordFile;
    }
    // lib.optionalAttrs (cfg.repositoryFile == null && cfg.repository != "") {
      RESTIC_REPOSITORY = cfg.repository;
    }
    // lib.optionalAttrs (cfg.repositoryFile != null) {
      RESTIC_REPOSITORY_FILE = cfg.repositoryFile;
    };

    # SOPS secret for restic password
    sops.secrets."service-restic-password" = {
      sopsFile = ../../../secrets.yaml;
      owner = cfg.user;
      inherit (cfg) group;
      mode = "0400";
    };

    # Configure Restic backup service
    services.restic.backups = {
      default = {
        inherit (cfg)
          user
          passwordFile
          paths
          exclude
          initialize
          pruneOpts
          extraOptions
          ;

        repository = mkIf (cfg.repository != "") cfg.repository;
        repositoryFile = mkIf (cfg.repositoryFile != null) cfg.repositoryFile;

        inherit (cfg) timerConfig;

        backupPrepareCommand = mkIf (cfg.backupPrepareCommand != null) cfg.backupPrepareCommand;
        backupCleanupCommand = mkIf (cfg.backupCleanupCommand != null) cfg.backupCleanupCommand;

        inherit (cfg) checkOpts;

        # Use rclone config if specified
        rcloneConfigFile = mkIf (cfg.rcloneConfigFile != null) cfg.rcloneConfigFile;

        # Add environment file if specified
      }
      // (
        if cfg.environmentFile != null then
          {
            inherit (cfg) environmentFile;
          }
        else
          { }
      );
    };

    # Create restic user if it doesn't exist
    users.users.${cfg.user} = {
      isSystemUser = true;
      inherit (cfg) group;
      home = cfg.dataDir;
      createHome = true;
      description = "Restic backup user";
    };

    users.groups.${cfg.group} = mkDefault { };

    # Ensure directories exist with correct permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0700 ${cfg.user} ${cfg.group} -"
    ];

    # Grant CAP_DAC_READ_SEARCH capability to bypass read permission checks
    # This allows the restic user to read all files without running as root
    systemd.services.restic-backups-default.serviceConfig = {
      AmbientCapabilities = [ "CAP_DAC_READ_SEARCH" ];
      CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" ];
    };
  };
}
