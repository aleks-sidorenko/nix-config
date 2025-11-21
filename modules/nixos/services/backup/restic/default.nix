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
in
{
  options.${namespace}.services.backup.restic = {
    enable = mkEnableOption "Enable Restic backup client";

    package = mkOpt types.package pkgs.restic "Restic package to use";

    user = mkOpt types.str "restic" "User to run Restic backups as";

    group = mkOpt types.str "restic" "Group to run Restic backups as";

    repository = mkOpt types.str "" "Restic repository URL (e.g., rest:http://server:8000/)";

    repositoryFile = mkOpt (types.nullOr types.path) null "Path to file containing repository URL";

    passwordFile = mkOpt types.path "/var/lib/restic/password" "Path to file containing repository password";

    paths = mkOpt (types.listOf types.str) [
      "/home"
      "/etc"
      "/var"
      "/root"
    ] "List of paths to backup";

    exclude = mkOpt (types.listOf types.str) [
      "*.tmp"
      "*.cache"
      "*.log"
      "/var/cache"
      "/var/tmp"
      "/var/log"
      "/home/*/.cache"
      "/home/*/.local/share/Trash"
    ] "List of patterns to exclude from backup";

    timerConfig = mkOpt types.attrs {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    } "Systemd timer configuration for automatic backups";

    pruneOpts = mkOpt (types.listOf types.str) [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
      "--keep-yearly 2"
    ] "Options for pruning old backups";

    initialize = mkBoolOpt false "Initialize the repository if it doesn't exist";

    checkOpts = mkOpt (types.listOf types.str) [
      "--read-data-subset=5%"
    ] "Options for checking repository integrity";

    backupPrepareCommand = mkOpt (types.nullOr types.str) null "Command to run before backup";

    backupCleanupCommand = mkOpt (types.nullOr types.str) null "Command to run after backup";

    extraOptions = mkOpt (types.listOf types.str) [ ] "Extra options to pass to restic";

    rcloneConfigFile = mkOpt (types.nullOr types.path) null "Path to rclone config file (if using rclone backend)";

    environmentFile = mkOpt (types.nullOr types.path) null "Environment file containing additional secrets";
  };

  config = mkIf cfg.enable {
    # Add Restic package to system packages
    environment.systemPackages = [ cfg.package ];

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
          extraOptions;

        repository = mkIf (cfg.repository != "") cfg.repository;
        repositoryFile = mkIf (cfg.repositoryFile != null) cfg.repositoryFile;

        timerConfig = cfg.timerConfig;

        backupPrepareCommand = mkIf (cfg.backupPrepareCommand != null) cfg.backupPrepareCommand;
        backupCleanupCommand = mkIf (cfg.backupCleanupCommand != null) cfg.backupCleanupCommand;

        checkOpts = cfg.checkOpts;

        # Use rclone config if specified
        rcloneConfigFile = mkIf (cfg.rcloneConfigFile != null) cfg.rcloneConfigFile;

        # Add environment file if specified
      } // (if cfg.environmentFile != null then {
        environmentFile = cfg.environmentFile;
      } else { });
    };

    # Create restic user if it doesn't exist
    users.users.${cfg.user} = mkIf (cfg.user == "restic") {
      isSystemUser = true;
      group = cfg.group;
      home = "/var/lib/restic";
      createHome = true;
      description = "Restic backup user";
    };

    users.groups.${cfg.group} = mkIf (cfg.group == "restic") { };

    # Ensure directories exist with correct permissions
    systemd.tmpfiles.rules = [
      "d /var/lib/restic 0700 ${cfg.user} ${cfg.group} -"
    ];
  };
}

